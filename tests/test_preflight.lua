local tests = {}

function tests.preflight_passes_for_server_game_cashier_display_and_admin_roles()
  local original = {
    fs = _G.fs,
    peripheral = _G.peripheral,
    rednet = _G.rednet,
    shell = _G.shell,
    term = _G.term,
    printError = _G.printError,
  }
  local previousConfig = package.loaded["shared.config"]
  local previousClient = package.loaded["client.shared.client"]

  local inventory = {
    list = function() return {} end,
    pushItems = function() return 0 end,
  }
  local monitor = {
    getSize = function() return 40, 20 end,
    isColor = function() return true end,
  }

  _G.fs = {
    exists = function(path)
      return path == "/casino/basalt.lua"
        or path == "/casino/basalt.version"
        or path:match("^/casino/data/.+%.json$") ~= nil
    end,
    getSize = function() return 277062 end,
    open = function(path)
      if path ~= "/casino/basalt.version" then return nil end
      return {
        readAll = function()
          return "2.5+a01ea6d577c92fcf76b5689f89eaf2920d011b82"
        end,
        close = function() end,
      }
    end,
  }
  _G.peripheral = {
    getNames = function() return { "left" } end,
    getType = function(name)
      if name == "left" then return "modem" end
      if name == "top" then return "monitor" end
      return "inventory"
    end,
    wrap = function(name)
      if name == "top" then return monitor end
      return inventory
    end,
  }
  _G.rednet = {
    open = function() end,
    lookup = function() return 10 end,
  }
  _G.shell = { setDir = function() end }
  _G.term = {
    getSize = function() return 51, 19 end,
    isColor = function() return true end,
  }
  _G.printError = function() end

  package.loaded["shared.config"] = {
    modemSide = nil,
    authorizedCashierIds = { 2 },
    authorizedAdminIds = { 1 },
    basaltVersion = "2.5+a01ea6d577c92fcf76b5689f89eaf2920d011b82",
    serverId = nil,
    protocol = "mc-casino.v1",
    serverHostname = "test-server",
    currencyItem = "minecraft:emerald",
    creditsPerItem = 1,
    cashierInput = "input",
    cashierVault = "vault",
    cashierOutput = "output",
    monitorSide = "top",
  }
  package.loaded["client.shared.client"] = {
    new = function()
      return {
        serverInfo = {
          currencyItem = "minecraft:emerald",
          creditsPerItem = 1,
        },
        connect = function() return true end,
      }
    end,
  }

  local ok, testError = pcall(function()
    for _, role in ipairs({
      "server", "slots", "cashier", "leaderboard", "admin",
    }) do
      local preflight = assert(loadfile("dev/preflight.lua"))
      preflight(role)
    end
  end)

  _G.fs = original.fs
  _G.peripheral = original.peripheral
  _G.rednet = original.rednet
  _G.shell = original.shell
  _G.term = original.term
  _G.printError = original.printError
  package.loaded["shared.config"] = previousConfig
  package.loaded["client.shared.client"] = previousClient

  assert(ok, testError)
end

return tests
