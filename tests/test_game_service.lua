local GameService = require("server.services.game_service")

local tests = {}

local function fixture(maximumBalance)
  local balance = 100
  local applied = {}
  local accounts = {}
  function accounts:get(playerId)
    return { id = playerId, balance = balance }
  end
  function accounts:change(requestId, _playerId, amount, kind)
    if applied[requestId] then return applied[requestId] end
    if balance + amount < 0 then return nil, "INSUFFICIENT_FUNDS" end
    balance = balance + amount
    local transaction = {
      requestId = requestId,
      amount = amount,
      kind = kind,
      balanceAfter = balance,
    }
    applied[requestId] = transaction
    return transaction
  end
  function accounts:findTransaction(requestId)
    return applied[requestId]
  end

  local jackpotAmount = 0
  local jackpotRequests = {}
  local jackpots = {}
  function jackpots:process(requestId, _name, amount, claim)
    if jackpotRequests[requestId] then return jackpotRequests[requestId] end
    local total = jackpotAmount + amount
    local result = {
      contribution = amount,
      claimed = claim and total or 0,
      after = claim and 0 or total,
    }
    jackpotAmount = result.after
    jackpotRequests[requestId] = result
    return result
  end

  local games = {}
  local responses = {}
  local gameRepository = {}
  function gameRepository:all() return games end
  function gameRepository:get(id) return games[id] end
  function gameRepository:findByRequestId(requestId)
    for _, game in pairs(games) do
      if game.createRequestId == requestId then return game end
    end
  end
  function gameRepository:findActive(playerId, gameType)
    for _, game in pairs(games) do
      if game.playerId == playerId
        and game.type == gameType
        and game.status == "ready"
        and not game.settled
      then
        return game
      end
    end
  end
  function gameRepository:save(game)
    games[game.id] = game
    return game
  end
  function gameRepository:getResponse(requestId) return responses[requestId] end
  function gameRepository:saveResponse(requestId, response)
    responses[requestId] = response
  end

  local service = GameService.new(
    accounts,
    jackpots,
    gameRepository,
    {
      minimumBet = 5,
      maximumBet = 500,
      blackjackDecks = 1,
      dealerHitsSoft17 = false,
      maximumBalance = maximumBalance or 1000000,
    }
  )
  return service,
    function() return balance end,
    gameRepository,
    function() return jackpotAmount end,
    applied
end

function tests.losing_slot_spin_deducts_one_bet()
  local service, balance = fixture()
  local originalRandom = math.random
  local values = { 1, 5, 8 }
  local index = 0
  math.random = function()
    index = index + 1
    return values[index]
  end
  local ok, result = pcall(service.create, service, "spin-1", "player", "slots", 10, 4)
  math.random = originalRandom
  assert(ok, result)
  assert(result.outcome == "lose")
  assert(balance() == 90)
end

function tests.duplicate_game_request_does_not_charge_twice()
  local service, balance = fixture()
  local originalRandom = math.random
  math.random = function() return 1 end
  local first = service:create("spin-2", "player", "slots", 5, 4)
  local second = service:create("spin-2", "player", "slots", 5, 4)
  math.random = originalRandom
  assert(first.gameId == second.gameId)
  assert(balance() == 105)
end

function tests.blackjack_push_returns_the_original_bet()
  local service, balance = fixture()
  local originalRandom = math.random
  math.random = function(maximum) return maximum end
  local created = service:create(
    "hand-1",
    "player",
    "blackjack",
    10,
    4
  )
  local finished = service:action(
    "hand-stand",
    "player",
    created.gameId,
    "stand",
    created.revision
  )
  math.random = originalRandom
  assert(finished.phase == "settled")
  assert(finished.outcome == "push")
  assert(balance() == 100)
end

function tests.player_cannot_accidentally_open_two_blackjack_hands()
  local service, balance = fixture()
  local originalRandom = math.random
  math.random = function(maximum) return maximum end
  local first = service:create("hand-a", "player", "blackjack", 10, 4)
  local second = service:create("hand-b", "player", "blackjack", 10, 4)
  math.random = originalRandom
  assert(first.gameId == second.gameId)
  assert(balance() == 90)
end

function tests.creating_game_is_resumed_once_after_restart()
  local service, balance, games = fixture()
  games:save({
    id = "game:pending",
    createRequestId = "pending-request",
    playerId = "player",
    senderId = 4,
    type = "slots",
    bet = 5,
    status = "creating",
    revision = 1,
    createdAt = 1,
    settled = false,
  })

  local originalRandom = math.random
  local values = { 1, 5, 8 }
  local index = 0
  math.random = function()
    index = index + 1
    return values[index]
  end
  service:recoverIncomplete()
  service:recoverIncomplete()
  math.random = originalRandom

  assert(games:get("game:pending").status == "ready")
  assert(games:get("game:pending").settled == true)
  assert(balance() == 95)
end

function tests.acceptance_games_do_not_change_live_statistics()
  local service, balance, _, jackpot, applied = fixture()
  local originalRandom = math.random
  local values = { 1, 5, 8 }
  local index = 0
  math.random = function()
    index = index + 1
    return values[index]
  end
  local ok, result = pcall(
    service.create,
    service,
    "acceptance-spin",
    "acceptance-player",
    "slots",
    5,
    1,
    {},
    true
  )
  math.random = originalRandom
  assert(ok, result)
  assert(result.phase == "settled")
  assert(balance() == 95)
  assert(jackpot() == 0)
  assert(applied["acceptance-spin:bet"].kind == "acceptance_game_bet")
  assert(#service:recentWins(10) == 0)
end

function tests.game_options_are_sanitized_before_persistence()
  local service, _, games = fixture()
  local originalRandom = math.random
  math.random = function() return 1 end
  local result = service:create(
    "roulette-sanitized",
    "player",
    "roulette",
    5,
    4,
    {
      choice = "red",
      injected = { string.rep("x", 200) },
    }
  )
  math.random = originalRandom
  assert(result.phase == "settled")
  local saved = games:get(result.gameId)
  assert(saved.options.choice == "red")
  assert(saved.options.injected == nil)
end

function tests.action_retry_recovers_when_response_cache_write_failed()
  local service, balance, games = fixture()
  local originalRandom = math.random
  math.random = function(maximum) return maximum end
  local created = service:create(
    "mines-create",
    "player",
    "mines",
    10,
    4,
    { mines = 3 }
  )
  math.random = originalRandom

  local saved = games:get(created.gameId)
  local safe
  for position = 1, 25 do
    if not saved.state.mines[tostring(position)] then safe = position break end
  end

  games.saveResponse = function()
    error("simulated response-cache failure")
  end
  local ok = pcall(
    service.action,
    service,
    "mines-reveal",
    "player",
    created.gameId,
    "reveal",
    created.revision,
    { position = safe }
  )
  assert(ok == false)
  assert(games:get(created.gameId).state.revealedCount == 1)

  local replay = service:action(
    "mines-reveal",
    "player",
    created.gameId,
    "reveal",
    created.revision,
    { position = safe }
  )
  assert(replay.revision == created.revision + 1)
  assert(#replay.revealed == 1)
  assert(games:get(created.gameId).state.revealedCount == 1)
  assert(balance() == 90)
end

function tests.large_win_is_credited_to_balance_cap_without_sticking_game()
  local service, balance, games, jackpot = fixture(120)
  local originalRandom = math.random
  math.random = function() return 11 end
  local result = service:create(
    "capped-slots",
    "player",
    "slots",
    5,
    4
  )
  math.random = originalRandom

  assert(result.phase == "settled")
  assert(result.payoutCapped == true)
  assert(result.grossPayout == 76)
  assert(result.payout == 25)
  assert(balance() == 120)
  assert(jackpot() == 1)
  local saved = games:get(result.gameId)
  assert(saved.settled == true)
  assert(saved.state.payout == 76)
  assert(saved.state.creditedPayout == 25)
end

return tests
