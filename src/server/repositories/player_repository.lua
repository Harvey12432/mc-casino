local JsonRepository = require("server.repositories.json_repository")
local util = require("shared.util")
local TransactionRepository = require("server.repositories.transaction_repository")
local validation = require("shared.validation")

local repository = {}

local function validPlayers(value)
  if type(value) ~= "table" then return false end
  for id, player in pairs(value) do
    if type(id) ~= "string"
      or #id > 32
      or type(player) ~= "table"
      or player.id ~= id
      or type(player.displayName) ~= "string"
      or not validation.isPlayerName(player.displayName)
      or player.displayName:lower() ~= id
      or type(player.balance) ~= "number"
      or player.balance < 0
      or player.balance >= math.huge
      or player.balance ~= math.floor(player.balance)
      or type(player.revision) ~= "number"
      or player.revision < 0
      or player.revision >= math.huge
      or player.revision ~= math.floor(player.revision)
      or type(player.processedRequests) ~= "table"
      or type(player.createdAt) ~= "number"
      or player.createdAt ~= player.createdAt
      or player.createdAt < 0
      or player.createdAt >= math.huge
    then
      return false
    end
    for requestId, transaction in pairs(player.processedRequests) do
      if type(requestId) ~= "string"
        or not TransactionRepository.validTransaction(transaction)
        or transaction.requestId ~= requestId
        or transaction.playerId ~= id
      then
        return false
      end
    end
  end
  return true
end

function repository.new(path)
  local store = JsonRepository.new(path or "/casino/data/players.json", {}, validPlayers)
  local instance = {}

  function instance:all()
    return util.copy(store:get())
  end

  function instance:get(id)
    return util.copy(store:get()[id])
  end

  function instance:save(player)
    local saved = util.copy(player)
    store:update(function(players)
      players[saved.id] = saved
    end)
    return util.copy(saved)
  end

  return instance
end

return repository
