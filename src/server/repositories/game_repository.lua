local JsonRepository = require("server.repositories.json_repository")
local StateValidation = require("server.games.state_validation")
local validation = require("shared.validation")
local util = require("shared.util")

local repository = {}

local gameTypes = {
  slots=true, blackjack=true, roulette=true, crash=true, mines=true,
  plinko=true, horse_racing=true, poker=true, craps=true, coin_flip=true,
}

local function integer(value, minimum)
  return type(value) == "number"
    and value < math.huge
    and value == math.floor(value)
    and value >= (minimum or 0)
end

local function validGame(id, game)
  if not validation.isNonEmptyString(id, 128)
    or type(game) ~= "table"
    or game.id ~= id
    or not gameTypes[game.type]
    or not validation.isNonEmptyString(game.createRequestId, 128)
    or not validation.isPlayerName(game.playerId)
    or game.playerId:lower() ~= game.playerId
    or not integer(game.senderId, 0)
    or not integer(game.bet, 1)
    or not integer(game.revision, 1)
    or not integer(game.createdAt, 0)
    or type(game.settled) ~= "boolean"
    or (game.acceptanceTest ~= nil and type(game.acceptanceTest) ~= "boolean")
    or (game.options ~= nil
      and not validation.isBoundedPayload(game.options, 16, 3, 64))
    or (game.settlementRequestId ~= nil
      and not validation.isNonEmptyString(game.settlementRequestId, 128))
  then
    return false
  end
  if game.status == "creating" then
    return game.state == nil and game.settled == false
  end
  if game.status ~= "ready"
    or type(game.state) ~= "table"
    or not StateValidation.valid(game.type, game.state)
    or (game.type == "blackjack" and game.state.originalBet ~= game.bet)
    or (game.type ~= "blackjack" and game.state.bet ~= game.bet)
  then
    return false
  end
  if game.settled then
    return game.state.phase == "settled"
      and type(game.settledAt) == "number"
      and integer(game.settledAt, 0)
  end
  return game.settledAt == nil
end

local function validGames(value)
  if type(value) ~= "table"
    or type(value.games) ~= "table"
    or type(value.responses) ~= "table"
  then
    return false
  end
  local seenCreateRequests = {}
  local activeGames = {}
  for id, game in pairs(value.games) do
    if not validGame(id, game) then return false end
    if seenCreateRequests[game.createRequestId] then return false end
    seenCreateRequests[game.createRequestId] = true
    if game.status == "ready" and not game.settled then
      local activeKey = game.playerId .. "\0" .. game.type
      if activeGames[activeKey] then return false end
      activeGames[activeKey] = true
    end
  end
  for requestId, response in pairs(value.responses) do
    if not validation.isNonEmptyString(requestId, 128)
      or type(response) ~= "table"
      or type(response.gameId) ~= "string"
      or not gameTypes[response.game]
      or not StateValidation.validView(response.game, response)
      or not validation.isBoundedPayload(response, 5000, 6, 256)
      or not value.games[response.gameId]
      or value.games[response.gameId].type ~= response.game
    then
      return false
    end
  end
  return true
end

function repository.new(path)
  local store = JsonRepository.new(
    path or "/casino/data/games.json",
    { games = {}, responses = {} },
    validGames
  )
  local instance = {}

  function instance:all()
    return util.copy(store:get().games)
  end

  function instance:get(id)
    return util.copy(store:get().games[id])
  end

  function instance:findByRequestId(requestId)
    for _, game in pairs(store:get().games) do
      if game.createRequestId == requestId then
        return util.copy(game)
      end
    end
    return nil
  end

  function instance:findActive(playerId, gameType)
    for _, game in pairs(store:get().games) do
      if game.playerId == playerId
        and game.type == gameType
        and game.status == "ready"
        and not game.settled
      then
        return util.copy(game)
      end
    end
    return nil
  end

  function instance:save(game)
    local saved = util.copy(game)
    store:update(function(value)
      value.games[saved.id] = saved
    end)
    return util.copy(saved)
  end

  function instance:getResponse(requestId)
    return util.copy(store:get().responses[requestId])
  end

  function instance:saveResponse(requestId, response)
    local saved = util.copy(response)
    store:update(function(value)
      value.responses[requestId] = saved
    end)
    return util.copy(saved)
  end

  return instance
end

return repository
