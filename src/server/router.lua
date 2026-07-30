local protocol = require("shared.protocol")

local router = {}
router.__index = router

local messages = {
  [protocol.types.ACCOUNT_VIEW] = "account",
  [protocol.types.CASHIER_DEPOSIT] = "account",
  [protocol.types.CASHIER_WITHDRAW] = "account",
  [protocol.types.CASHIER_REFUND] = "account",
  [protocol.types.CASHIER_STATUS] = "account",
  [protocol.types.GAME_CREATE] = "game",
  [protocol.types.GAME_ACTION] = "game",
  [protocol.types.GAME_VIEW] = "game",
  [protocol.types.ADMIN_COMMAND] = "admin",
  [protocol.types.DISPLAY_SUBSCRIBE] = "display",
}

local errorMessages = {
  BAD_REQUEST = "The request was invalid.",
  INVALID_PLAYER = "Enter a valid player name.",
  INVALID_BET = "The bet is outside the casino limits.",
  INVALID_OPTIONS = "The selected game option is invalid.",
  UNKNOWN_GAME = "That game is not available.",
  PLAYER_NOT_FOUND = "The player account does not exist.",
  INSUFFICIENT_FUNDS = "The player does not have enough credits.",
  BALANCE_LIMIT = "That operation would exceed the maximum account balance.",
  UNAUTHORIZED = "Log in before using this terminal.",
  SESSION_EXPIRED = "The session expired; please log in again.",
  FORBIDDEN = "This computer is not authorised for that operation.",
  GAME_NOT_FOUND = "The game could not be found.",
  GAME_FINISHED = "That game has already finished.",
  INVALID_ACTION = "That action is not available.",
  STALE_STATE = "The game changed; refresh and try again.",
  MAINTENANCE = "The casino is temporarily in maintenance mode.",
  INTERNAL_ERROR = "The casino server encountered an error.",
  WRONG_CASINO = "This terminal belongs to another casino.",
  REQUEST_CONFLICT = "That operation ID was already used differently.",
}

function router.new(config, dependencies)
  return setmetatable({
    config = config,
    accountHandler = dependencies.accountHandler,
    gameHandler = dependencies.gameHandler,
    adminHandler = dependencies.adminHandler,
    sessionService = dependencies.sessionService,
    systemRepository = dependencies.systemRepository,
  }, router)
end

function router:ok(requestId, payload)
  return {
    type = protocol.responses.OK,
    requestId = requestId,
    payload = payload or {},
  }
end

function router:failure(requestId, code)
  return {
    type = protocol.responses.ERROR,
    requestId = requestId,
    error = {
      code = code,
      message = errorMessages[code] or errorMessages.INTERNAL_ERROR,
      retryable = code == "STALE_STATE" or code == "INTERNAL_ERROR",
    },
  }
end

function router:route(senderId, message)
  if message.casinoId ~= self.config.casinoId then
    return self:failure(message.requestId, "WRONG_CASINO")
  end

  if message.type == protocol.types.HELLO then
    return self:ok(message.requestId, {
      casinoId = self.config.casinoId,
      hostname = self.config.serverHostname,
      currencyItem = self.config.currencyItem,
      creditsPerItem = self.config.creditsPerItem,
      minimumBet = self.config.minimumBet,
      maximumBet = self.config.maximumBet,
      maximumBalance = self.config.maximumBalance,
      status = self.systemRepository:get().maintenance
        and "maintenance"
        or "online",
      games = {
        "slots", "blackjack", "roulette", "crash", "mines", "plinko",
        "horse_racing", "poker", "craps", "coin_flip",
      },
    })
  end

  if message.type == protocol.types.SESSION_OPEN then
    local result, routeError = self.accountHandler:openSession(senderId, message)
    if not result then return self:failure(message.requestId, routeError) end
    return self:ok(message.requestId, result)
  end

  -- The display snapshot contains public casino-floor information only. Keeping
  -- it outside the player-session path lets monitor computers boot unattended
  -- without creating a fake player account.
  if message.type == protocol.types.DISPLAY_SUBSCRIBE then
    if self.systemRepository:get().disabledMachines[tostring(senderId)] then
      return self:failure(message.requestId, "FORBIDDEN")
    end
    return self:ok(message.requestId, self.adminHandler:publicSnapshot())
  end

  local session, sessionError = self.sessionService:authenticate(
    senderId,
    message.sessionToken
  )
  if not session then return self:failure(message.requestId, sessionError) end

  if self.systemRepository:get().disabledMachines[tostring(senderId)]
    and session.role ~= "admin"
  then
    return self:failure(message.requestId, "FORBIDDEN")
  end

  if message.type == protocol.types.SESSION_CLOSE then
    self.sessionService:close(message.sessionToken)
    return self:ok(message.requestId, {})
  end

  local target = messages[message.type]
  if not target then return self:failure(message.requestId, "BAD_REQUEST") end
  if self.systemRepository:get().maintenance
    and message.type == protocol.types.GAME_CREATE
    and session.role ~= "admin"
  then
    return self:failure(message.requestId, "MAINTENANCE")
  end

  local result, routeError
  if target == "account" then
    result, routeError = self.accountHandler:handle(senderId, message, session)
  elseif target == "game" then
    result, routeError = self.gameHandler:handle(senderId, message, session)
  elseif target == "admin" then
    result, routeError = self.adminHandler:handle(message, session)
  end

  if not result then
    return self:failure(message.requestId, routeError or "BAD_REQUEST")
  end
  return self:ok(message.requestId, result)
end

return router
