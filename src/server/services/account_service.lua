local accountService = {}
accountService.__index = accountService

local function normalizeName(name)
  local trimmed = tostring(name):match("^%s*(.-)%s*$")
  return trimmed:lower()
end

local function sameOperation(transaction, playerId, amount, kind, referenceId)
  return transaction.playerId == playerId
    and transaction.amount == amount
    and transaction.kind == kind
    and transaction.referenceId == referenceId
end

function accountService.new(
  playerRepository,
  transactionService,
  startingBalance,
  maximumBalance
)
  return setmetatable({
    playerRepository = playerRepository,
    transactionService = transactionService,
    startingBalance = startingBalance or 0,
    maximumBalance = maximumBalance or 1000000000,
  }, accountService)
end

function accountService:getOrCreate(displayName)
  local id = normalizeName(displayName)
  local player = self.playerRepository:get(id)
  if not player then
    player = {
      id = id,
      displayName = tostring(displayName):match("^%s*(.-)%s*$"),
      balance = self.startingBalance,
      revision = 0,
      processedRequests = {},
      createdAt = os.epoch("utc"),
    }
    self.playerRepository:save(player)
  end
  return player
end

function accountService:get(playerId)
  return self.playerRepository:get(normalizeName(playerId))
end

function accountService:change(requestId, playerId, amount, kind, referenceId)
  local player = self:get(playerId)
  if not player then
    return nil, "PLAYER_NOT_FOUND"
  end

  player.processedRequests = player.processedRequests or {}
  local processed = player.processedRequests[requestId]
  if processed then
    if not sameOperation(processed, player.id, amount, kind, referenceId) then
      return nil, "REQUEST_CONFLICT"
    end
    if not self.transactionService:find(requestId) then
      self.transactionService:record(processed)
    end
    return processed
  end

  local existing = self.transactionService:find(requestId)
  if existing then
    if not sameOperation(existing, player.id, amount, kind, referenceId) then
      return nil, "REQUEST_CONFLICT"
    end
    return existing
  end

  if type(amount) ~= "number"
    or amount ~= math.floor(amount)
    or amount == math.huge
    or amount == -math.huge
  then
    return nil, "BAD_REQUEST"
  end
  local nextBalance = player.balance + amount
  if nextBalance < 0 then
    return nil, "INSUFFICIENT_FUNDS"
  end
  if nextBalance > self.maximumBalance then
    return nil, "BALANCE_LIMIT"
  end

  local transaction = {
    id = "txn:" .. requestId,
    requestId = requestId,
    playerId = player.id,
    kind = kind,
    amount = amount,
    balanceAfter = nextBalance,
    referenceId = referenceId,
    timestamp = os.epoch("utc"),
  }

  player.balance = nextBalance
  player.revision = (player.revision or 0) + 1
  player.processedRequests[requestId] = transaction
  self.playerRepository:save(player)
  self.transactionService:record(transaction)
  return transaction
end

function accountService:findTransaction(requestId)
  return self.transactionService:find(requestId)
end

function accountService:list()
  local result = {}
  for _, player in pairs(self.playerRepository:all()) do
    table.insert(result, {
      id = player.id,
      displayName = player.displayName,
      balance = player.balance,
      revision = player.revision,
    })
  end
  table.sort(result, function(a, b)
    if a.balance == b.balance then return a.displayName < b.displayName end
    return a.balance > b.balance
  end)
  return result
end

function accountService:repairTransactions()
  for _, player in pairs(self.playerRepository:all()) do
    for requestId, transaction in pairs(player.processedRequests or {}) do
      if not self.transactionService:find(requestId) then
        self.transactionService:record(transaction)
      end
    end
  end
end

return accountService
