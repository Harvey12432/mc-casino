local protocol = require("shared.protocol")
local validation = require("shared.validation")

local handler = {}
handler.__index = handler

function handler.new(accountService, sessionService)
  return setmetatable({
    accountService = accountService,
    sessionService = sessionService,
  }, handler)
end

function handler:openSession(senderId, message)
  local current, playerOrError = self.sessionService:open(
    senderId,
    message.payload.player
  )
  if not current then return nil, playerOrError end
  return {
    sessionToken = current.token,
    role = current.role,
    player = {
      id = playerOrError.id,
      displayName = playerOrError.displayName,
      balance = playerOrError.balance,
    },
  }
end

function handler:handle(senderId, message, session)
  if message.type == protocol.types.ACCOUNT_VIEW then
    local playerId = session.playerId
    if (session.role == "cashier" or session.role == "admin")
      and validation.isPlayerName(message.payload.player)
    then
      playerId = message.payload.player
    end
    local player = self.accountService:get(playerId)
    if not player then return nil, "PLAYER_NOT_FOUND" end
    return {
      player = {
        id = player.id,
        displayName = player.displayName,
        balance = player.balance,
      },
    }
  end

  local isCashierMessage = message.type == protocol.types.CASHIER_DEPOSIT
    or message.type == protocol.types.CASHIER_WITHDRAW
    or message.type == protocol.types.CASHIER_REFUND
    or message.type == protocol.types.CASHIER_STATUS
  if isCashierMessage then
    if session.role ~= "cashier" and session.role ~= "admin" then
      return nil, "FORBIDDEN"
    end
    local operationId = message.payload.operationId
    if not validation.isNonEmptyString(operationId, 128) then
      return nil, "BAD_REQUEST"
    end

    if message.type == protocol.types.CASHIER_STATUS then
      local transaction = self.accountService:findTransaction(operationId)
      if not transaction then return { status = "unknown" } end
      if transaction.kind ~= "cashier_deposit"
        and transaction.kind ~= "cashier_withdrawal"
      then
        return { status = "unknown" }
      end
      local refund = self.accountService:findTransaction(operationId .. ":refund")
      return {
        status = refund and "refunded" or "committed",
        transaction = transaction,
        refund = refund,
      }
    end

    if message.type == protocol.types.CASHIER_REFUND then
      local original = self.accountService:findTransaction(operationId)
      local deliveredAmount = message.payload.deliveredAmount
      if not original
        or original.kind ~= "cashier_withdrawal"
        or type(deliveredAmount) ~= "number"
        or deliveredAmount ~= math.floor(deliveredAmount)
        or deliveredAmount < 0
        or deliveredAmount > -original.amount
      then
        return nil, "BAD_REQUEST"
      end
      local refundAmount = -original.amount - deliveredAmount
      if refundAmount == 0 then
        return {
          status = "delivered",
          transaction = original,
          refund = nil,
        }
      end
      local reference = "cashier_refund:" .. operationId
      local refund, refundError = self.accountService:change(
        operationId .. ":refund",
        original.playerId,
        refundAmount,
        "cashier_delivery_refund",
        reference
      )
      if not refund then return nil, refundError end
      return {
        status = deliveredAmount == 0 and "refunded" or "partially_delivered",
        transaction = original,
        refund = refund,
      }
    end

    local target = message.payload.player
    local amount = message.payload.amount
    if not validation.isPlayerName(target)
      or not validation.isCreditAmount(amount)
    then
      return nil, "BAD_REQUEST"
    end

    local player = self.accountService:getOrCreate(target)
    local withdrawing = message.type == protocol.types.CASHIER_WITHDRAW
    local direction = withdrawing and -1 or 1
    local kind = withdrawing and "cashier_withdrawal" or "cashier_deposit"
    local reference = "cashier:" .. senderId
    local transaction, transactionError = self.accountService:change(
      operationId,
      player.id,
      direction * amount,
      kind,
      reference
    )
    if not transaction then return nil, transactionError end
    return {
      player = {
        id = player.id,
        displayName = player.displayName,
        balance = transaction.balanceAfter,
      },
      transaction = transaction,
    }
  end

  return nil, "BAD_REQUEST"
end

return handler
