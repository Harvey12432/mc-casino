local tests = {}

local colourNames = {
  "black", "blue", "brown", "cyan", "gray", "green", "lightBlue",
  "lightGray", "lime", "magenta", "orange", "pink", "purple", "red",
  "white", "yellow",
}

local function fakeBasalt()
  local basalt = {
    frames = {},
    scheduled = {},
    runs = 0,
  }

  local function element(kind)
    local value = {
      kind = kind,
      text = "",
      children = {},
      items = {},
    }
    return setmetatable(value, {
      __index = function(self, method)
        if method == "getText" then
          return function(current) return current.text end
        elseif method == "clear" then
          return function(current)
            current.items = {}
            return current
          end
        elseif method == "addItem" then
          return function(current, item)
            table.insert(current.items, item)
            return current
          end
        elseif method == "onClick" then
          return function(current, callback)
            current.click = callback
            return current
          end
        elseif method:match("^add") then
          return function(current)
            local child = element(method:sub(4):lower())
            table.insert(current.children, child)
            return child
          end
        elseif method == "setText" then
          return function(current, text)
            current.text = tostring(text)
            return current
          end
        end
        return function(current)
          return current
        end
      end,
    })
  end

  function basalt.getMainFrame()
    local frame = element("frame")
    table.insert(basalt.frames, frame)
    return frame
  end

  function basalt.createFrame()
    local frame = element("frame")
    table.insert(basalt.frames, frame)
    return frame
  end

  function basalt.schedule(callback)
    table.insert(basalt.scheduled, callback)
  end

  function basalt.run()
    basalt.runs = basalt.runs + 1
  end

  return basalt
end

function tests.every_client_ui_constructs_on_the_basalt_contract()
  local original = {
    colors = _G.colors,
    peripheral = _G.peripheral,
    settings = _G.settings,
    sleep = _G.sleep,
  }
  local previousConfig = package.loaded["shared.config"]
  local previousBasalt = package.loaded["basalt"]

  local colours = {}
  for index, name in ipairs(colourNames) do colours[name] = 2 ^ (index - 1) end
  _G.colors = colours

  local settingsData = {}
  _G.settings = {
    get = function(key) return settingsData[key] end,
    set = function(key, value) settingsData[key] = value end,
    unset = function(key) settingsData[key] = nil end,
    save = function() end,
  }
  _G.sleep = function() end
  _G.peripheral = {
    wrap = function()
      return {
        list = function() return {} end,
        pushItems = function() return 0 end,
        getSize = function() return 40, 20 end,
        isColor = function() return true end,
      }
    end,
  }

  local basalt = fakeBasalt()
  package.loaded["basalt"] = basalt
  package.loaded["shared.config"] = {
    monitorSide = "top",
    cashierInput = "input",
    cashierVault = "vault",
    cashierOutput = "output",
    currencyItem = "minecraft:emerald",
    creditsPerItem = 1,
  }

  local client = {
    player = { id = "alice", displayName = "Alice", balance = 100 },
    serverInfo = { minimumBet = 5, maximumBet = 500 },
    request = function()
      error("A queued request ran during UI construction")
    end,
    logout = function() end,
  }

  local gameRoles = {
    "slots", "roulette", "crash", "mines", "plinko", "horse_racing",
    "poker", "craps", "coin_flip",
  }
  local recoveryKey = "casino.craps.gameId.alice"
  settingsData[recoveryKey] = "craps-resume"
  for _, role in ipairs(gameRoles) do
    local scheduledBefore = #basalt.scheduled
    require("client." .. role .. ".ui").run(client)
    if role == "craps" then
      assert(
        #basalt.scheduled == scheduledBefore + 1,
        "Craps did not queue recovery for its saved active round"
      )
      local requestedType, requestedPayload
      client.request = function(_, messageType, payload)
        requestedType, requestedPayload = messageType, payload
        return {
          game = "craps",
          gameId = "craps-resume",
          phase = "point",
          revision = 2,
          dice = { 3, 3 },
          total = 6,
          point = 6,
          payout = 0,
        }
      end
      basalt.scheduled[scheduledBefore + 1]()
      assert(requestedType == require("shared.protocol").types.GAME_VIEW)
      assert(requestedPayload.gameId == "craps-resume")
      assert(settingsData[recoveryKey] == "craps-resume")
      client.request = function()
        error("A queued request ran during UI construction")
      end
    end
  end

  local blackjackGame = require("client.blackjack.game").new()
  require("client.blackjack.ui").run(client, blackjackGame)
  require("client.cashier.ui").run(client)
  require("client.leaderboard.ui").run(client)
  require("client.admin.ui").run(client)

  assert(#basalt.frames == 13)
  assert(basalt.runs == 13)
  for _, frame in ipairs(basalt.frames) do
    assert(#frame.children >= 4, "UI frame was created without its controls")
  end
  assert(#basalt.scheduled >= 2, "Expected initial admin/display work to be queued")

  package.loaded["shared.config"] = previousConfig
  package.loaded["basalt"] = previousBasalt
  _G.colors = original.colors
  _G.peripheral = original.peripheral
  _G.settings = original.settings
  _G.sleep = original.sleep
end

return tests
