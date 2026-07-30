local util = require("shared.util")
local blackjack = require("server.games.blackjack")
local slots = require("server.games.slots")
local roulette = require("server.games.roulette")
local crash = require("server.games.crash")
local mines = require("server.games.mines")
local plinko = require("server.games.plinko")
local horseRacing = require("server.games.horse_racing")
local poker = require("server.games.poker")
local craps = require("server.games.craps")
local coinFlip = require("server.games.coin_flip")

local engines = {
  slots = slots,
  blackjack = blackjack,
  roulette = roulette,
  crash = crash,
  mines = mines,
  plinko = plinko,
  horse_racing = horseRacing,
  poker = poker,
  craps = craps,
  coin_flip = coinFlip,
}

local gameService = {}
gameService.__index = gameService

local function sanitizedOptions(gameType, options)
  if gameType == "roulette" or gameType == "coin_flip" then
    return { choice = options.choice }
  elseif gameType == "mines" then
    return { mines = tonumber(options.mines) or 3 }
  elseif gameType == "horse_racing" then
    return { horse = tonumber(options.horse) }
  end
  return {}
end

local function rulesFrom(config)
  return {
    decks = config.blackjackDecks or 6,
    dealerHitsSoft17 = config.dealerHitsSoft17 == true,
    blackjackPayoutNumerator = 3,
    blackjackPayoutDenominator = 2,
  }
end

function gameService.new(
  accountService,
  jackpotService,
  gameRepository,
  config
)
  return setmetatable({
    accountService = accountService,
    jackpotService = jackpotService,
    gameRepository = gameRepository,
    config = config,
    blackjackRules = rulesFrom(config),
    engines = engines,
  }, gameService)
end

function gameService:validateBet(bet)
  return type(bet) == "number"
    and bet == math.floor(bet)
    and bet >= self.config.minimumBet
    and bet <= self.config.maximumBet
end

function gameService:view(game)
  local engine = assert(self.engines[game.type], "Unknown game type")
  local view = engine.view(game)
  if game.state.creditedPayout ~= nil then
    view.grossPayout = view.payout
    view.payout = game.state.creditedPayout
    view.payoutCapped = true
  end
  return view
end

function gameService:settle(game, requestId)
  if game.settled then return end
  local payout = game.state.payout or 0

  if game.type == "slots" and not game.acceptanceTest then
    local contribution = slots.jackpotContribution(
      game.state.bet,
      game.state.rulesVersion
    )
    local jackpotResult = self.jackpotService:process(
      game.id .. ":jackpot",
      "slots",
      contribution,
      game.state.jackpot
    )
    if jackpotResult.claimed > 0 then
      payout = payout + jackpotResult.claimed
      game.state.jackpotAmount = jackpotResult.claimed
      game.state.payout = payout
    end
  end

  local creditedPayout = payout
  local payoutRequestId = requestId .. ":payout"
  local existingPayout = self.accountService:findTransaction(payoutRequestId)
  if existingPayout then
    creditedPayout = existingPayout.amount
  elseif payout > 0 then
    local player = assert(self.accountService:get(game.playerId))
    local capacity = math.max(
      0,
      (self.config.maximumBalance or math.huge) - player.balance
    )
    creditedPayout = math.min(payout, capacity)
  end

  if creditedPayout < payout then
    game.state.creditedPayout = creditedPayout
    game.state.payoutCapped = true
    local jackpotRemainder = math.min(
      payout - creditedPayout,
      game.state.jackpotAmount or 0
    )
    if jackpotRemainder > 0 and not game.acceptanceTest then
      self.jackpotService:process(
        game.id .. ":jackpot-remainder",
        "slots",
        jackpotRemainder,
        false
      )
    end
  end

  if creditedPayout > 0 and not existingPayout then
    local transaction, payoutError = self.accountService:change(
      payoutRequestId,
      game.playerId,
      creditedPayout,
      game.acceptanceTest and "acceptance_game_payout" or "game_payout",
      game.id
    )
    if not transaction then error(payoutError) end
  end
  game.settled = true
  game.settledAt = os.epoch("utc")
end

function gameService:completeCreation(game)
  if game.status == "ready" then
    if game.state.phase == "settled" and not game.settled then
      self:settle(game, game.settlementRequestId or game.createRequestId)
      self.gameRepository:save(game)
    end
    return self:view(game)
  end
  local debit, debitError = self.accountService:change(
    game.createRequestId .. ":bet",
    game.playerId,
    -game.bet,
    game.acceptanceTest and "acceptance_game_bet" or "game_bet",
    game.id
  )
  if not debit then return nil, debitError end

  local engine = self.engines[game.type]
  if game.type == "slots" then
    game.state = slots.spin(game.bet)
  else
    game.state = engine.create(
      game.bet,
      game.options or {},
      game.type == "blackjack" and self.blackjackRules or {}
    )
  end
  game.status = "ready"
  game.settlementRequestId = game.createRequestId
  self.gameRepository:save(game)

  if game.state.phase == "settled" then
    self:settle(game, game.settlementRequestId)
    self.gameRepository:save(game)
  end
  return self:view(game)
end

function gameService:create(
  requestId,
  playerId,
  gameType,
  bet,
  senderId,
  options,
  acceptanceTest
)
  local previous = self.gameRepository:findByRequestId(requestId)
  if previous then return self:completeCreation(previous) end
  local engine = self.engines[gameType]
  if not engine then return nil, "UNKNOWN_GAME" end
  if gameType == "blackjack" or gameType == "crash" or gameType == "mines"
    or gameType == "poker" or gameType == "craps"
  then
    local active = self.gameRepository:findActive(playerId, gameType)
    if active then return self:view(active) end
  end
  if not self:validateBet(bet) then return nil, "INVALID_BET" end
  options = options or {}
  if engine.validate then
    local valid, validationError = engine.validate(options)
    if not valid then return nil, validationError or "INVALID_OPTIONS" end
  end
  options = sanitizedOptions(gameType, options)

  local player = self.accountService:get(playerId)
  if not player or player.balance < bet then return nil, "INSUFFICIENT_FUNDS" end

  local game = {
    id = util.newId("game"),
    createRequestId = requestId,
    playerId = playerId,
    senderId = senderId,
    type = gameType,
    bet = bet,
    options = options,
    status = "creating",
    revision = 1,
    createdAt = os.epoch("utc"),
    settled = false,
    acceptanceTest = acceptanceTest == true,
  }
  self.gameRepository:save(game)
  return self:completeCreation(game)
end

function gameService:action(
  requestId,
  playerId,
  gameId,
  action,
  expectedRevision,
  payload
)
  local previous = self.gameRepository:getResponse(requestId)
  if previous then return previous end

  local game = self.gameRepository:get(gameId)
  if not game or game.playerId ~= playerId then return nil, "GAME_NOT_FOUND" end
  -- The state change is persisted before its response cache. If the latter
  -- write fails, a retry with the same request ID must return the committed
  -- view instead of applying the action again or reporting GAME_FINISHED.
  if game.settlementRequestId == requestId then
    return self:view(game)
  end
  local engine = self.engines[game.type]
  if not engine or not engine.action then return nil, "INVALID_ACTION" end
  if expectedRevision and expectedRevision ~= game.revision then
    return nil, "STALE_STATE"
  end

  if action == "double" then
    if not blackjack.canDouble(game.state) then return nil, "INVALID_ACTION" end
    local debit, debitError = self.accountService:change(
      requestId .. ":double",
      playerId,
      -game.state.originalBet,
      game.acceptanceTest and "acceptance_game_double" or "game_double",
      game.id
    )
    if not debit then return nil, debitError end
  end

  local changed, actionError
  if game.type == "blackjack" then
    changed, actionError = engine.action(game.state, action, self.blackjackRules)
  else
    changed, actionError = engine.action(game.state, action, payload or {}, {})
  end
  if not changed then return nil, actionError end

  game.revision = game.revision + 1
  game.settlementRequestId = requestId
  self.gameRepository:save(game)
  if game.state.phase == "settled" then
    self:settle(game, requestId)
    self.gameRepository:save(game)
  end
  local view = self:view(game)
  self.gameRepository:saveResponse(requestId, view)
  return view
end

function gameService:recoverIncomplete()
  for _, game in pairs(self.gameRepository:all()) do
    if game.status == "creating" then
      self:completeCreation(game)
    elseif game.status == "ready" then
      local engine = self.engines[game.type]
      if engine and engine.tick and game.state.phase ~= "settled" then
        engine.tick(game.state)
        self.gameRepository:save(game)
      end
      if game.state
      and game.state.phase == "settled"
      and not game.settled
      then
        self:settle(
          game,
          game.settlementRequestId or game.createRequestId
        )
        self.gameRepository:save(game)
      end
    end
  end
end

function gameService:get(playerId, gameId)
  local game = self.gameRepository:get(gameId)
  if not game or game.playerId ~= playerId then return nil, "GAME_NOT_FOUND" end
  local engine = self.engines[game.type]
  if engine and engine.tick and game.state.phase ~= "settled" then
    engine.tick(game.state)
    game.revision = game.revision + 1
    self.gameRepository:save(game)
    if game.state.phase == "settled" then
      game.settlementRequestId = game.id .. ":automatic"
      self:settle(game, game.settlementRequestId)
      self.gameRepository:save(game)
    end
  end
  return self:view(game)
end

function gameService:recentWins(limit)
  local wins = {}
  for _, game in pairs(self.gameRepository:all()) do
    local paid = game.state.creditedPayout or game.state.payout or 0
    if game.settled
      and not game.acceptanceTest
      and paid > game.state.bet
    then
      table.insert(wins, {
        playerId = game.playerId,
        game = game.type,
        payout = paid,
        timestamp = game.settledAt,
      })
    end
  end
  table.sort(wins, function(a, b) return a.timestamp > b.timestamp end)
  while #wins > (limit or 10) do table.remove(wins) end
  return wins
end

return gameService
