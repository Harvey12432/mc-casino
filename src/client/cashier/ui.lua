local components = require("client.shared.components")
local protocol = require("shared.protocol")
local config = require("shared.config")
local util = require("shared.util")
local Inventory = require("client.cashier.inventory")

local ui = {}
local pendingKey = "casino.cashier.pending"

local function savePending(operation)
  settings.set(pendingKey, operation)
  settings.save()
end

local function clearPending()
  settings.unset(pendingKey)
  settings.save()
end

function ui.run(client)
  local app = components.app("CASINO CASHIER", "Restart-safe item transfers")
  local inventory = Inventory.new()
  local pending = settings.get(pendingKey)
  local armedKind
  local armedUntil = 0

  local playerInput = app.main:addInput()
    :setPosition(2, 6)
    :setSize(20, 1)
    :setPlaceholder("Player name")
    :setBackground(colors.gray)
    :setForeground(colors.white)

  local amountInput = app.main:addInput()
    :setPosition(2, 8)
    :setSize(12, 1)
    :setPlaceholder("Item count")
    :setBackground(colors.gray)
    :setForeground(colors.white)

  local function finish(message)
    clearPending()
    pending = nil
    components.setStatus(app, message, false)
  end

  local function failAndClear(message)
    clearPending()
    pending = nil
    components.setStatus(app, message, true)
  end

  local function pendingFailure()
    components.setStatus(app, "Operation pending; press RECONCILE", true)
  end

  local function commitFailure(message, errorCode)
    if not errorCode or errorCode == "INTERNAL_ERROR" then
      pendingFailure()
      return
    end
    if pending and pending.kind == "deposit"
      and pending.phase == "deposit_committing"
    then
      local returned = inventory:rollbackDeposit(pending.items)
      if returned == pending.items then
        failAndClear("Deposit rejected; items returned: " .. tostring(message))
      else
        components.setStatus(app, "Rejected deposit needs operator review", true)
      end
      return
    end
    if pending and pending.phase == "withdraw_requesting" then
      failAndClear("Withdrawal rejected: " .. tostring(message))
      return
    end
    pendingFailure()
  end

  local function requestRefund(operation, deliveredCredits)
    operation.phase = "withdraw_refunding"
    operation.deliveredAmount = deliveredCredits
    savePending(operation)
    components.request(app, client, protocol.types.CASHIER_REFUND, {
      operationId = operation.operationId,
      deliveredAmount = deliveredCredits,
    }, function()
      finish(("%d item(s) delivered; remainder refunded"):format(
        deliveredCredits / config.creditsPerItem
      ))
    end, pendingFailure)
  end

  local function dispense(operation)
    operation.phase = "withdraw_dispensing"
    savePending(operation)
    local moved = inventory:withdraw(operation.items)
    local deliveredCredits = moved * config.creditsPerItem
    if moved == operation.items then
      finish(("%d item(s) dispensed to %s"):format(moved, operation.player))
    else
      requestRefund(operation, deliveredCredits)
    end
  end

  local function commit(operation)
    local messageType = operation.kind == "deposit"
      and protocol.types.CASHIER_DEPOSIT
      or protocol.types.CASHIER_WITHDRAW
    components.request(app, client, messageType, {
      operationId = operation.operationId,
      player = operation.player,
      amount = operation.credits,
    }, function(result)
      if operation.kind == "deposit" then
        finish(("%s now has %d credits"):format(
          result.player.displayName,
          result.player.balance
        ))
      else
        dispense(operation)
      end
    end, commitFailure)
  end

  local function reconcile()
    if not pending then
      components.setStatus(app, "No pending cashier operation", false)
      return
    end
    if pending.phase == "deposit_moving"
      or pending.phase == "withdraw_dispensing"
    then
      components.setStatus(
        app,
        "Physical transfer was interrupted; operator review required",
        true
      )
      return
    end
    components.request(app, client, protocol.types.CASHIER_STATUS, {
      operationId = pending.operationId,
    }, function(result)
      if result.status == "unknown" then
        commit(pending)
      elseif pending.kind == "deposit" then
        finish("Deposit was already committed")
      elseif result.status == "refunded"
        or result.status == "partially_delivered"
      then
        finish("Withdrawal refund was already committed")
      elseif pending.phase == "withdraw_refunding" then
        requestRefund(pending, pending.deliveredAmount or 0)
      else
        dispense(pending)
      end
    end, pendingFailure)
  end

  local function submit(kind)
    if pending then
      components.setStatus(app, "Reconcile the pending operation first", true)
      return
    end
    local player = playerInput:getText()
    local items = tonumber(amountInput:getText())
    if player == "" or not player:match("^[A-Za-z0-9_]+$") or #player > 32 then
      components.setStatus(
        app,
        "Enter a player name using letters, numbers, or underscore",
        true
      )
      return
    end
    if not items or items < 1 or items ~= math.floor(items) then
      components.setStatus(app, "Enter a whole item count", true)
      return
    end
    if kind == "withdraw" and inventory:availableForWithdrawal() < items then
      components.setStatus(app, "Casino vault lacks currency items", true)
      return
    end
    local now = os.epoch("utc")
    if armedKind ~= kind or now > armedUntil then
      armedKind = kind
      armedUntil = now + 10000
      components.setStatus(
        app,
        ("Press %s again to confirm %d item(s) for %s")
          :format(kind:upper(), items, player),
        false
      )
      return
    end
    armedKind = nil
    armedUntil = 0
    local operation = {
      operationId = util.newId("cashier"),
      kind = kind,
      player = player,
      items = items,
      credits = items * config.creditsPerItem,
      phase = kind == "deposit" and "deposit_moving" or "withdraw_requesting",
    }
    pending = operation
    savePending(operation)

    if kind == "deposit" then
      if inventory:availableForDeposit() < items then
        finish("Not enough currency items in input")
        return
      end
      local moved = inventory:deposit(items)
      if moved ~= items then
        local returned = inventory:rollbackDeposit(moved)
        if returned == moved then
          finish("Deposit transfer failed; all moved items returned")
        else
          components.setStatus(app, "Physical transfer needs operator review", true)
        end
        return
      end
      operation.phase = "deposit_committing"
      savePending(operation)
    end
    commit(operation)
  end

  app.main:addButton()
    :setText("DEPOSIT")
    :setPosition(2, 11)
    :setSize(12, 3)
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(function() submit("deposit") end)

  app.main:addButton()
    :setText("WITHDRAW")
    :setPosition(16, 11)
    :setSize(12, 3)
    :setBackground(colors.orange)
    :setForeground(colors.black)
    :onClick(function() submit("withdraw") end)

  app.main:addButton()
    :setText("BALANCE")
    :setPosition(30, 11)
    :setSize(10, 3)
    :setBackground(colors.blue)
    :setForeground(colors.white)
    :onClick(function()
      components.request(app, client, protocol.types.ACCOUNT_VIEW, {
        player = playerInput:getText(),
      }, function(result)
        components.setStatus(app, ("%s has %d credits"):format(
          result.player.displayName,
          result.player.balance
        ), false)
      end)
    end)

  app.main:addButton()
    :setText("RECONCILE")
    :setPosition(42, 11)
    :setSize(9, 3)
    :setBackground(colors.purple)
    :setForeground(colors.white)
    :onClick(reconcile)

  if pending then
    components.setStatus(app, "Pending operation found; press RECONCILE", true)
  end
  components.run(app)
end

return ui
