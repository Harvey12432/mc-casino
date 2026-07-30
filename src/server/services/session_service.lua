local util = require("shared.util")
local validation = require("shared.validation")

local sessionService = {}
sessionService.__index = sessionService

local function contains(values, wanted)
  for _, value in ipairs(values or {}) do
    if value == wanted then return true end
  end
  return false
end

function sessionService.new(config, accountService)
  return setmetatable({
    config = config,
    accountService = accountService,
    sessions = {},
  }, sessionService)
end

function sessionService:roleFor(senderId)
  if contains(self.config.authorizedAdminIds, senderId) then return "admin" end
  if contains(self.config.authorizedCashierIds, senderId) then return "cashier" end
  return "player"
end

function sessionService:open(senderId, playerName)
  if not validation.isPlayerName(playerName) then
    return nil, "INVALID_PLAYER"
  end

  local player = self.accountService:getOrCreate(playerName)
  -- Sender binding is the primary trust boundary, but an unpredictable suffix
  -- also prevents another terminal from guessing a live token from its
  -- computer ID and timestamp alone.
  local token = ("%s:%08x"):format(
    util.newId("session"),
    math.random(0, 0x7fffffff)
  )
  local current = {
    token = token,
    senderId = senderId,
    playerId = player.id,
    role = self:roleFor(senderId),
    expiresAt = os.epoch("utc") + (self.config.sessionTimeout * 1000),
  }
  self.sessions[token] = current
  return current, player
end

function sessionService:authenticate(senderId, token)
  local current = self.sessions[token]
  if not current or current.senderId ~= senderId then
    return nil, "UNAUTHORIZED"
  end
  if current.expiresAt < os.epoch("utc") then
    self.sessions[token] = nil
    return nil, "SESSION_EXPIRED"
  end
  current.expiresAt = os.epoch("utc") + (self.config.sessionTimeout * 1000)
  return current
end

function sessionService:close(token)
  self.sessions[token] = nil
end

return sessionService
