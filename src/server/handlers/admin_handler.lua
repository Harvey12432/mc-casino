local validation = require("shared.validation")
local handler = {}
handler.__index = handler

function handler.new(
  accountService,
  transactionService,
  jackpotService,
  gameService,
  systemRepository,
  config
)
  return setmetatable({
    accountService = accountService,
    transactionService = transactionService,
    jackpotService = jackpotService,
    gameService = gameService,
    systemRepository = systemRepository,
    config = config or {},
  }, handler)
end

function handler:publicSnapshot()
  local state = self.systemRepository:get()
  local players = self.accountService:list()
  local leaders = {}
  local acceptancePlayerId = tostring(
    self.config.acceptancePlayerId or "casino_test"
  ):lower()
  for _, player in ipairs(players) do
    if player.id ~= acceptancePlayerId then
      table.insert(leaders, player)
      if #leaders == 10 then break end
    end
  end
  return {
    jackpot = self.jackpotService:get("slots"),
    leaders = leaders,
    recentWins = self.gameService:recentWins(10),
    maintenance = state.maintenance,
  }
end

function handler:handle(message, session)
  local command = message.payload.command
  if command == "snapshot" then
    return self:publicSnapshot()
  end
  if session.role ~= "admin" then return nil, "FORBIDDEN" end

  if command == "balances" then
    return { players = self.accountService:list() }
  elseif command == "transactions" then
    return { transactions = self.transactionService:list(100) }
  elseif command == "summary" then
    local result = self:publicSnapshot()
    result.houseProfit = self.transactionService:houseProfit()
    return result
  elseif command == "maintenance" then
    local state = self.systemRepository:get()
    state.maintenance = message.payload.enabled == true
    self.systemRepository:save(state)
    return { maintenance = state.maintenance }
  elseif command == "machines" then
    return {
      disabledMachines = self.systemRepository:get().disabledMachines,
    }
  elseif command == "machine" then
    local computerId = tonumber(message.payload.computerId)
    if not computerId or computerId ~= math.floor(computerId) then
      return nil, "BAD_REQUEST"
    end
    local state = self.systemRepository:get()
    local key = tostring(computerId)
    state.disabledMachines[key] = message.payload.disabled == true or nil
    self.systemRepository:save(state)
    return {
      computerId = computerId,
      disabled = state.disabledMachines[key] == true,
    }
  elseif command == "adjust" then
    local target = message.payload.player
    local amount = message.payload.amount
    if not validation.isPlayerName(target)
      or type(amount) ~= "number"
      or amount ~= math.floor(amount)
      or amount == math.huge
      or amount == -math.huge
      or amount == 0
    then
      return nil, "BAD_REQUEST"
    end
    local player = self.accountService:getOrCreate(target)
    local transaction, transactionError = self.accountService:change(
      message.requestId,
      player.id,
      amount,
      "admin_adjustment",
      "admin:" .. session.senderId
    )
    if not transaction then return nil, transactionError end
    return { transaction = transaction }
  end

  return nil, "BAD_REQUEST"
end

return handler
