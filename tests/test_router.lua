local protocol = require("shared.protocol")
local TransactionService = require("server.services.transaction_service")
local AccountService = require("server.services.account_service")
local JackpotService = require("server.services.jackpot_service")
local SessionService = require("server.services.session_service")
local GameService = require("server.services.game_service")
local AccountHandler = require("server.handlers.account_handler")
local GameHandler = require("server.handlers.game_handler")
local AdminHandler = require("server.handlers.admin_handler")
local Router = require("server.router")

local tests = {}

local function fixture()
  local players = {}
  local playerRepository = {}
  function playerRepository:get(id) return players[id] end
  function playerRepository:save(player)
    players[player.id] = player
    return player
  end
  function playerRepository:all() return players end

  local transactions = {}
  local transactionRepository = {}
  function transactionRepository:all() return transactions end
  function transactionRepository:findByRequestId(requestId)
    for _, transaction in ipairs(transactions) do
      if transaction.requestId == requestId then return transaction end
    end
  end
  function transactionRepository:append(transaction)
    table.insert(transactions, transaction)
    return transaction
  end

  local jackpot = 0
  local jackpotRequests = {}
  local jackpotRepository = {}
  function jackpotRepository:get() return jackpot end
  function jackpotRepository:process(requestId, _name, contribution, claim)
    if jackpotRequests[requestId] then return jackpotRequests[requestId] end
    local total = jackpot + contribution
    local result = {
      contribution = contribution,
      claimed = claim and total or 0,
      after = claim and 0 or total,
    }
    jackpot = result.after
    jackpotRequests[requestId] = result
    return result
  end

  local games = {}
  local responses = {}
  local gameRepository = {}
  function gameRepository:all() return games end
  function gameRepository:get(id) return games[id] end
  function gameRepository:save(game) games[game.id] = game return game end
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
  function gameRepository:getResponse(requestId) return responses[requestId] end
  function gameRepository:saveResponse(requestId, response)
    responses[requestId] = response
  end

  local systemState = { maintenance = false, disabledMachines = {} }
  local systemRepository = {}
  function systemRepository:get() return systemState end
  function systemRepository:save() end

  local config = {
    casinoId = "test-casino",
    serverHostname = "test-server",
    startingBalance = 0,
    minimumBet = 5,
    maximumBet = 100,
    maximumBalance = 1000,
    blackjackDecks = 1,
    dealerHitsSoft17 = false,
    sessionTimeout = 60,
    authorizedAdminIds = { 1 },
    authorizedCashierIds = { 2 },
    currencyItem = "minecraft:emerald",
    creditsPerItem = 4,
  }

  local transactionService = TransactionService.new(transactionRepository)
  local accountService = AccountService.new(
    playerRepository,
    transactionService,
    config.startingBalance,
    config.maximumBalance
  )
  local jackpotService = JackpotService.new(jackpotRepository)
  local sessionService = SessionService.new(config, accountService)
  local gameService = GameService.new(
    accountService,
    jackpotService,
    gameRepository,
    config
  )
  local accountHandler = AccountHandler.new(accountService, sessionService)
  local gameHandler = GameHandler.new(gameService)
  local adminHandler = AdminHandler.new(
    accountService,
    transactionService,
    jackpotService,
    gameService,
    systemRepository,
    config
  )

  return Router.new(config, {
    accountHandler = accountHandler,
    gameHandler = gameHandler,
    adminHandler = adminHandler,
    sessionService = sessionService,
    systemRepository = systemRepository,
  })
end

local requestSequence = 0
local function send(router, senderId, messageType, payload, token, requestId)
  requestSequence = requestSequence + 1
  return router:route(senderId, {
    type = messageType,
    requestId = requestId or ("router-test:" .. requestSequence),
    casinoId = "test-casino",
    sessionToken = token,
    payload = payload or {},
  })
end

local function login(router, senderId, name)
  local response = send(router, senderId, protocol.types.SESSION_OPEN, {
    player = name,
  })
  assert(response.type == protocol.responses.OK)
  return response.payload.sessionToken, response.payload
end

function tests.complete_protocol_flow()
  local router = fixture()
  local wrongCasino = router:route(3, {
    type = protocol.types.HELLO,
    requestId = "wrong",
    casinoId = "wrong",
    payload = {},
  })
  assert(wrongCasino.error.code == "WRONG_CASINO")

  local hello = send(router, 99, protocol.types.HELLO, {})
  assert(hello.payload.currencyItem == "minecraft:emerald")
  assert(hello.payload.creditsPerItem == 4)
  assert(hello.payload.maximumBalance == 1000)
  local publicSnapshot = send(
    router,
    99,
    protocol.types.DISPLAY_SUBSCRIBE,
    {},
    nil
  )
  assert(publicSnapshot.type == protocol.responses.OK)

  local adminToken, adminSession = login(router, 1, "Owner")
  local cashierToken, cashierSession = login(router, 2, "Cashier")
  local playerToken, playerSession = login(router, 3, "Alice")
  assert(adminSession.role == "admin")
  assert(cashierSession.role == "cashier")
  assert(playerSession.role == "player")

  local adjusted = send(router, 1, protocol.types.ADMIN_COMMAND, {
    command = "adjust",
    player = "Alice",
    amount = 20,
  }, adminToken)
  assert(adjusted.type == protocol.responses.OK)

  local balance = send(
    router,
    3,
    protocol.types.ACCOUNT_VIEW,
    {},
    playerToken
  )
  assert(balance.payload.player.balance == 20)

  local originalRandom = math.random
  local values = { 1, 5, 8 }
  local index = 0
  math.random = function()
    index = index + 1
    return values[index]
  end
  local spin = send(router, 3, protocol.types.GAME_CREATE, {
    game = "slots",
    bet = 5,
  }, playerToken, "protocol-spin")
  local replay = send(router, 3, protocol.types.GAME_CREATE, {
    game = "slots",
    bet = 5,
  }, playerToken, "protocol-spin")
  math.random = originalRandom
  assert(spin.type == protocol.responses.OK)
  assert(spin.payload.phase == "settled")
  assert(spin.payload.gameId == replay.payload.gameId)

  balance = send(router, 3, protocol.types.ACCOUNT_VIEW, {}, playerToken)
  assert(balance.payload.player.balance == 15)

  local forbiddenDeposit = send(router, 3, protocol.types.CASHIER_DEPOSIT, {
    operationId = "cashier:forbidden",
    player = "Alice",
    amount = 5,
  }, playerToken)
  assert(forbiddenDeposit.error.code == "FORBIDDEN")

  local deposit = send(router, 2, protocol.types.CASHIER_DEPOSIT, {
    operationId = "cashier:deposit-1",
    player = "Alice",
    amount = 5,
  }, cashierToken)
  assert(deposit.payload.player.balance == 20)

  local depositStatus = send(router, 2, protocol.types.CASHIER_STATUS, {
    operationId = "cashier:deposit-1",
  }, cashierToken)
  assert(depositStatus.payload.status == "committed")

  local withdrawal = send(router, 2, protocol.types.CASHIER_WITHDRAW, {
    operationId = "cashier:withdraw-1",
    player = "Alice",
    amount = 5,
  }, cashierToken)
  assert(withdrawal.payload.player.balance == 15)

  local refund = send(router, 2, protocol.types.CASHIER_REFUND, {
    operationId = "cashier:withdraw-1",
    deliveredAmount = 2,
  }, cashierToken)
  assert(refund.payload.status == "partially_delivered")
  assert(refund.payload.refund.amount == 3)

  local duplicateRefund = send(router, 2, protocol.types.CASHIER_REFUND, {
    operationId = "cashier:withdraw-1",
    deliveredAmount = 2,
  }, cashierToken)
  assert(duplicateRefund.payload.refund.requestId
    == refund.payload.refund.requestId)

  local conflictingRefund = send(router, 2, protocol.types.CASHIER_REFUND, {
    operationId = "cashier:withdraw-1",
    deliveredAmount = 1,
  }, cashierToken)
  assert(conflictingRefund.error.code == "REQUEST_CONFLICT")

  local forgedRefund = send(router, 2, protocol.types.CASHIER_REFUND, {
    operationId = "cashier:not-a-withdrawal",
    deliveredAmount = 0,
  }, cashierToken)
  assert(forgedRefund.error.code == "BAD_REQUEST")

  local conflictingDeposit = send(router, 2, protocol.types.CASHIER_DEPOSIT, {
    operationId = "cashier:deposit-1",
    player = "Alice",
    amount = 10,
  }, cashierToken)
  assert(conflictingDeposit.error.code == "REQUEST_CONFLICT")

  local maintenance = send(router, 1, protocol.types.ADMIN_COMMAND, {
    command = "maintenance",
    enabled = true,
  }, adminToken)
  assert(maintenance.payload.maintenance == true)
  local blockedGame = send(router, 3, protocol.types.GAME_CREATE, {
    game = "slots",
    bet = 5,
  }, playerToken)
  assert(blockedGame.error.code == "MAINTENANCE")

  send(router, 1, protocol.types.ADMIN_COMMAND, {
    command = "maintenance",
    enabled = false,
  }, adminToken)
  send(router, 1, protocol.types.ADMIN_COMMAND, {
    command = "machine",
    computerId = 3,
    disabled = true,
  }, adminToken)
  local disabled = send(router, 3, protocol.types.ACCOUNT_VIEW, {}, playerToken)
  assert(disabled.error.code == "FORBIDDEN")

  send(router, 1, protocol.types.ADMIN_COMMAND, {
    command = "machine",
    computerId = 3,
    disabled = false,
  }, adminToken)
  send(router, 1, protocol.types.ADMIN_COMMAND, {
    command = "adjust",
    player = "casino_test",
    amount = 1000,
  }, adminToken)
  local snapshot = send(
    router,
    3,
    protocol.types.DISPLAY_SUBSCRIBE,
    {},
    nil
  )
  assert(snapshot.type == protocol.responses.OK)
  assert(type(snapshot.payload.leaders) == "table")
  assert(type(snapshot.payload.recentWins) == "table")
  for _, player in ipairs(snapshot.payload.leaders) do
    assert(player.id ~= "casino_test")
  end
end

return tests
