local config = require("shared.config")
local network = require("shared.network")
local util = require("shared.util")

local client = {}

function client.new()
  return setmetatable({
    serverId = config.serverId,
    sessionToken = nil,
    role = nil,
    player = nil,
    playerName = nil,
    serverInfo = nil,
  }, { __index = client })
end

function client:login(playerName)
  local payload, loginError = self:request("session.open", {
    player = playerName,
  })
  if not payload then return nil, loginError end
  self.sessionToken = payload.sessionToken
  self.role = payload.role
  self.player = payload.player
  self.playerName = playerName
  return payload
end

function client:connect()
  network.open(config.modemSide)
  self.serverId = self.serverId
    or network.lookup(config.protocol, config.serverHostname)
  if not self.serverId then
    return false, "Casino server was not discovered"
  end
  local serverInfo, helloError = self:request("system.hello", {}, false)
  if not serverInfo then
    self.serverId = nil
    return false, helloError
  end
  self.serverInfo = serverInfo
  return true
end

function client:send(messageType, payload)
  if not self.serverId then
    return false, "Casino server is unavailable"
  end

  local message = {
    type = messageType,
    requestId = util.newId("req"),
    casinoId = config.casinoId,
    sessionToken = self.sessionToken,
    payload = payload or {},
  }

  return network.send(self.serverId, message, config.protocol)
end

function client:request(messageType, payload, allowReauthentication)
  if not self.serverId then
    return nil, "Casino server is unavailable"
  end
  if allowReauthentication == nil then allowReauthentication = true end

  local requestId = util.newId("req")
  local message = {
    type = messageType,
    requestId = requestId,
    casinoId = config.casinoId,
    sessionToken = self.sessionToken,
    payload = payload or {},
  }

  for attempt = 1, config.requestRetries + 1 do
    network.send(self.serverId, message, config.protocol)
    local deadline = os.startTimer(config.requestTimeout)

    while true do
      local event, first, second, third = os.pullEvent()
      if event == "timer" and first == deadline then
        break
      end

      if event == "rednet_message"
        and first == self.serverId
        and third == config.protocol
        and type(second) == "table"
        and second.requestId == requestId
      then
        if second.type == "response.ok" then
          return second.payload or {}
        end
        local requestError =
          second.error and second.error.message or "Server rejected request"
        local errorCode =
          second.error and second.error.code or "UNKNOWN_ERROR"
        if errorCode == "INTERNAL_ERROR"
          and attempt <= config.requestRetries
        then
          -- The server may have committed the operation before a later
          -- response-cache write failed. Reuse this exact request ID so the
          -- persisted operation marker can return the committed result.
          break
        end
        if allowReauthentication
          and messageType ~= "session.open"
          and self.playerName
          and (errorCode == "UNAUTHORIZED" or errorCode == "SESSION_EXPIRED")
        then
          local session = self:login(self.playerName)
          if session then
            return self:request(messageType, payload, false)
          end
        end
        return nil, requestError, errorCode
      end
    end
  end

  return nil, "Casino server timed out"
end

function client:logout()
  if self.sessionToken then
    self:send("session.close", {})
  end
  self.sessionToken = nil
  self.role = nil
  self.player = nil
  self.playerName = nil
end

return client
