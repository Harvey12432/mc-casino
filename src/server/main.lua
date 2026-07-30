local config = require("shared.config")
local logger = require("shared.logger")
local network = require("shared.network")
local validation = require("shared.validation")

local PlayerRepository = require("server.repositories.player_repository")
local TransactionRepository = require("server.repositories.transaction_repository")
local JackpotRepository = require("server.repositories.jackpot_repository")
local GameRepository = require("server.repositories.game_repository")
local SystemRepository = require("server.repositories.system_repository")

local TransactionService = require("server.services.transaction_service")
local AccountService = require("server.services.account_service")
local JackpotService = require("server.services.jackpot_service")
local SessionService = require("server.services.session_service")
local GameService = require("server.services.game_service")

local AccountHandler = require("server.handlers.account_handler")
local GameHandler = require("server.handlers.game_handler")
local AdminHandler = require("server.handlers.admin_handler")
local Router = require("server.router")

math.randomseed(os.epoch("utc"))

local transactionService = TransactionService.new(TransactionRepository.new())
local accountService = AccountService.new(
  PlayerRepository.new(),
  transactionService,
  config.startingBalance,
  config.maximumBalance
)
local jackpotService = JackpotService.new(JackpotRepository.new())
local sessionService = SessionService.new(config, accountService)
local gameService = GameService.new(
  accountService,
  jackpotService,
  GameRepository.new(),
  config
)
local systemRepository = SystemRepository.new()

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
local requestRouter = Router.new(config, {
  accountHandler = accountHandler,
  gameHandler = gameHandler,
  adminHandler = adminHandler,
  sessionService = sessionService,
  systemRepository = systemRepository,
})

-- Force every persistent store to validate or recover before accepting bets.
accountService:list()
transactionService:list(0)
accountService:repairTransactions()
jackpotService:get("slots")
gameService:recentWins(0)
gameService:recoverIncomplete()
systemRepository:get()

network.open(config.modemSide)
rednet.host(config.protocol, config.serverHostname)
logger.info("Casino server is online as " .. config.serverHostname)

while true do
  local senderId, message = network.receive(config.protocol)
  if validation.isRequest(message) then
    local success, response = pcall(requestRouter.route, requestRouter, senderId, message)
    if not success then
      logger.error(response)
      response = requestRouter:failure(message.requestId, "INTERNAL_ERROR")
    end
    network.send(senderId, response, config.protocol)
  else
    logger.warn("Rejected malformed request from computer " .. tostring(senderId))
  end
end
