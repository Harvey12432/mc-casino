local tests = {}

function tests.client_discovers_server_and_opens_session()
  local originalPeripheral = _G.peripheral
  local originalRednet = _G.rednet
  local originalPullEvent = os.pullEvent
  local originalStartTimer = os.startTimer

  local sent
  local sentTypes = {}
  _G.peripheral = {
    getNames = function() return { "left" } end,
    getType = function() return "modem" end,
  }
  _G.rednet = {
    open = function() end,
    lookup = function() return 10 end,
    send = function(recipientId, message, protocolName)
      sent = {
        recipientId = recipientId,
        message = message,
        protocolName = protocolName,
      }
      table.insert(sentTypes, message.type)
      return true
    end,
    receive = function() error("receive should not be called") end,
  }
  os.startTimer = function() return 77 end
  os.pullEvent = function()
    assert(sent, "Client did not send a request")
    local payload
    if sent.message.type == "system.hello" then
      payload = {
        casinoId = "main-floor",
        currencyItem = "minecraft:emerald",
        creditsPerItem = 1,
      }
    else
      payload = {
        sessionToken = "session:test",
        role = "player",
        player = {
          id = "alice",
          displayName = "Alice",
          balance = 25,
        },
      }
    end
    return "rednet_message", 10, {
      type = "response.ok",
      requestId = sent.message.requestId,
      payload = payload,
    }, "mc-casino.v1"
  end

  package.loaded["shared.config"] = nil
  package.loaded["shared.network"] = nil
  package.loaded["client.shared.client"] = nil
  local Client = require("client.shared.client")
  local client = Client.new()
  local ok, testError = pcall(function()
    assert(client:connect())
    local session, loginError = client:login("Alice")
    assert(session, loginError)
    assert(client.serverId == 10)
    assert(client.sessionToken == "session:test")
    assert(client.player.balance == 25)
    assert(client.serverInfo.currencyItem == "minecraft:emerald")
    assert(sentTypes[1] == "system.hello")
    assert(sentTypes[2] == "session.open")
    assert(sent.protocolName == "mc-casino.v1")
  end)

  _G.peripheral = originalPeripheral
  _G.rednet = originalRednet
  os.pullEvent = originalPullEvent
  os.startTimer = originalStartTimer
  assert(ok, testError)
end

function tests.client_reauthenticates_after_server_session_loss()
  local originalPeripheral = _G.peripheral
  local originalRednet = _G.rednet
  local originalPullEvent = os.pullEvent
  local originalStartTimer = os.startTimer
  local sent
  local loginCount = 0
  local accountCount = 0

  _G.peripheral = {
    getNames = function() return { "left" } end,
    getType = function() return "modem" end,
  }
  _G.rednet = {
    open = function() end,
    lookup = function() return 10 end,
    send = function(_, message)
      sent = message
      if message.type == "session.open" then loginCount = loginCount + 1 end
      if message.type == "account.view" then accountCount = accountCount + 1 end
      return true
    end,
  }
  os.startTimer = function() return 77 end
  os.pullEvent = function()
    local response = {
      requestId = sent.requestId,
      type = "response.ok",
      payload = {},
    }
    if sent.type == "system.hello" then
      response.payload = {
        casinoId = "main-floor",
        currencyItem = "minecraft:emerald",
        creditsPerItem = 1,
      }
    elseif sent.type == "session.open" then
      response.payload = {
        sessionToken = "session:" .. loginCount,
        role = "player",
        player = { id="alice", displayName="Alice", balance=25 },
      }
    elseif sent.type == "account.view" and accountCount == 1 then
      response.type = "response.error"
      response.payload = nil
      response.error = {
        code = "UNAUTHORIZED",
        message = "Log in before using this terminal.",
      }
    elseif sent.type == "account.view" then
      response.payload = {
        player = { id="alice", displayName="Alice", balance=30 },
      }
    end
    return "rednet_message", 10, response, "mc-casino.v1"
  end

  package.loaded["shared.config"] = nil
  package.loaded["shared.network"] = nil
  package.loaded["client.shared.client"] = nil
  local Client = require("client.shared.client")
  local client = Client.new()
  local ok, testError = pcall(function()
    assert(client:connect())
    assert(client:login("Alice"))
    local account, accountError = client:request("account.view", {})
    assert(account, accountError)
    assert(account.player.balance == 30)
    assert(loginCount == 2)
    assert(client.sessionToken == "session:2")
  end)

  _G.peripheral = originalPeripheral
  _G.rednet = originalRednet
  os.pullEvent = originalPullEvent
  os.startTimer = originalStartTimer
  assert(ok, testError)
end

function tests.client_retries_internal_error_with_the_same_request_id()
  local originalPeripheral = _G.peripheral
  local originalRednet = _G.rednet
  local originalPullEvent = os.pullEvent
  local originalStartTimer = os.startTimer
  local sent
  local sentIds = {}

  _G.peripheral = {
    getNames = function() return { "left" } end,
    getType = function() return "modem" end,
  }
  _G.rednet = {
    open = function() end,
    send = function(_, message)
      sent = message
      table.insert(sentIds, message.requestId)
      return true
    end,
  }
  os.startTimer = function() return 77 end
  os.pullEvent = function()
    if #sentIds == 1 then
      return "rednet_message", 10, {
        type = "response.error",
        requestId = sent.requestId,
        error = {
          code = "INTERNAL_ERROR",
          message = "The casino server encountered an error.",
          retryable = true,
        },
      }, "mc-casino.v1"
    end
    return "rednet_message", 10, {
      type = "response.ok",
      requestId = sent.requestId,
      payload = { recovered = true },
    }, "mc-casino.v1"
  end

  package.loaded["shared.config"] = nil
  package.loaded["shared.network"] = nil
  package.loaded["client.shared.client"] = nil
  local Client = require("client.shared.client")
  local client = Client.new()
  client.serverId = 10
  local ok, testError = pcall(function()
    local result, requestError = client:request("game.action", {})
    assert(result, requestError)
    assert(result.recovered == true)
    assert(#sentIds == 2)
    assert(sentIds[1] == sentIds[2])
  end)

  _G.peripheral = originalPeripheral
  _G.rednet = originalRednet
  os.pullEvent = originalPullEvent
  os.startTimer = originalStartTimer
  assert(ok, testError)
end

return tests
