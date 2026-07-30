local JsonRepository = require("server.repositories.json_repository")
local util = require("shared.util")

local repository = {}

function repository.validTransaction(transaction)
  return type(transaction) == "table"
    and type(transaction.id) == "string"
    and #transaction.id <= 132
    and type(transaction.requestId) == "string"
    and #transaction.requestId >= 1
    and #transaction.requestId <= 128
    and transaction.id == "txn:" .. transaction.requestId
    and type(transaction.playerId) == "string"
    and #transaction.playerId >= 1
    and #transaction.playerId <= 32
    and type(transaction.amount) == "number"
    and transaction.amount ~= math.huge
    and transaction.amount ~= -math.huge
    and transaction.amount == math.floor(transaction.amount)
    and type(transaction.kind) == "string"
    and #transaction.kind >= 1
    and #transaction.kind <= 64
    and type(transaction.balanceAfter) == "number"
    and transaction.balanceAfter >= 0
    and transaction.balanceAfter < math.huge
    and transaction.balanceAfter == math.floor(transaction.balanceAfter)
    and type(transaction.referenceId) == "string"
    and #transaction.referenceId >= 1
    and #transaction.referenceId <= 256
    and type(transaction.timestamp) == "number"
    and transaction.timestamp == transaction.timestamp
    and transaction.timestamp >= 0
    and transaction.timestamp < math.huge
end

local function validTransactions(value)
  if type(value) ~= "table" then return false end
  local count = 0
  local seenRequests = {}
  for index, transaction in pairs(value) do
    if type(index) ~= "number"
      or index ~= math.floor(index)
      or index < 1
      or not repository.validTransaction(transaction)
    then
      return false
    end
    if seenRequests[transaction.requestId] then return false end
    seenRequests[transaction.requestId] = true
    count = count + 1
  end
  return count == #value
end

function repository.new(path)
  local store = JsonRepository.new(
    path or "/casino/data/transactions.json",
    {},
    validTransactions
  )
  local instance = {}

  function instance:all()
    return util.copy(store:get())
  end

  function instance:findByRequestId(requestId)
    for _, transaction in ipairs(store:get()) do
      if transaction.requestId == requestId then
        return util.copy(transaction)
      end
    end
    return nil
  end

  function instance:append(transaction)
    local saved = util.copy(transaction)
    assert(
      not self:findByRequestId(saved.requestId),
      "Duplicate transaction request ID " .. tostring(saved.requestId)
    )
    store:update(function(transactions)
      table.insert(transactions, saved)
    end)
    return util.copy(saved)
  end

  return instance
end

return repository
