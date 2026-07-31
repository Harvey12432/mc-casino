local tests = {}

local function runWizard(role, answers, peripheralTypes, initialConfig, storedRole)
  local original = {
    colors = _G.colors,
    fs = _G.fs,
    peripheral = _G.peripheral,
    print = _G.print,
    read = _G.read,
    term = _G.term,
    write = _G.write,
  }
  local files = {
    ["/casino/config.lua"] = initialConfig,
    ["/casino/role"] = storedRole or role,
  }
  local answerIndex = 0
  local names = {}
  for name in pairs(peripheralTypes) do names[#names + 1] = name end
  table.sort(names)

  _G.colors = {
    black = 1, white = 2, lime = 4, lightGray = 8,
    green = 16, yellow = 32, cyan = 64, red = 128, orange = 256,
  }
  _G.term = {
    isColor = function() return true end,
    setTextColor = function() end,
    setBackgroundColor = function() end,
    clear = function() end,
    setCursorPos = function() end,
  }
  _G.print = function() end
  _G.write = function() end
  _G.read = function()
    answerIndex = answerIndex + 1
    assert(answers[answerIndex] ~= nil, "Setup requested an unexpected answer")
    return answers[answerIndex]
  end
  _G.peripheral = {
    getNames = function() return names end,
    hasType = function(name, wanted) return peripheralTypes[name] == wanted end,
    getType = function(name) return peripheralTypes[name] end,
    wrap = function(name)
      if peripheralTypes[name] == "inventory" then
        return { list = function() return {} end, pushItems = function() return 0 end }
      end
      return {}
    end,
  }
  _G.fs = {
    exists = function(path) return files[path] ~= nil end,
    open = function(path, mode)
      if mode == "r" then
        if files[path] == nil then return nil end
        return {
          readAll = function() return files[path] end,
          close = function() end,
        }
      end
      assert(mode == "w")
      local buffer = ""
      return {
        write = function(value) buffer = buffer .. value end,
        close = function() files[path] = buffer end,
      }
    end,
    copy = function(source, destination)
      assert(files[source] ~= nil, "Missing copy source " .. source)
      files[destination] = files[source]
    end,
    delete = function(path) files[path] = nil end,
    move = function(source, destination)
      assert(files[source] ~= nil, "Missing move source " .. source)
      files[destination], files[source] = files[source], nil
    end,
  }

  local ok, testError = pcall(function()
    local setup = assert(loadfile("installer/setup.lua"))
    if role then setup(role) else setup() end
  end)

  _G.colors = original.colors
  _G.fs = original.fs
  _G.peripheral = original.peripheral
  _G.print = original.print
  _G.read = original.read
  _G.term = original.term
  _G.write = original.write
  assert(ok, testError)
  return files, answerIndex
end

local function decodeConfig(contents)
  local chunk, compileError = load(contents, "@saved-config", "t", {})
  assert(chunk, compileError)
  local ok, result = pcall(chunk)
  assert(ok and type(result) == "table")
  return result
end

function tests.server_setup_validates_and_safely_saves_role_specific_settings()
  local originalConfig = [[return {
    casinoId = "main-floor",
    serverHostname = "mc-casino-main",
    currencyItem = "minecraft:emerald",
    creditsPerItem = 1,
    minimumBet = 5,
    maximumBet = 500,
    maximumBalance = 1000000000,
    blackjackDecks = 6,
    dealerHitsSoft17 = false,
    authorizedCashierIds = {},
    authorizedAdminIds = {},
  }]]
  local files, answersUsed = runWizard("server", {
    "", "", "", "12, 12, 14", "13", "", "", "", "", "", "", "yes", "",
  }, { left = "modem" }, originalConfig)
  local saved = decodeConfig(files["/casino/config.lua"])
  assert(saved.modemSide == "left")
  assert(#saved.authorizedCashierIds == 2)
  assert(saved.authorizedCashierIds[1] == 12)
  assert(saved.authorizedCashierIds[2] == 14)
  assert(saved.authorizedAdminIds[1] == 13)
  assert(saved.dealerHitsSoft17 == true)
  assert(files["/casino/config.before-setup.lua"] == originalConfig)
  assert(answersUsed == 13)
end

function tests.cashier_setup_detects_distinct_inventory_peripherals_and_role_file()
  local files = runWizard(nil, {
    "", "", "", "1", "3", "2", "", "", "",
  }, {
    input = "inventory",
    left = "modem",
    output = "inventory",
    vault = "inventory",
  }, "return {}", "cashier")
  local saved = decodeConfig(files["/casino/config.lua"])
  assert(saved.modemSide == "left")
  assert(saved.cashierInput == "input")
  assert(saved.cashierVault == "vault")
  assert(saved.cashierOutput == "output")
  assert(saved.currencyItem == "minecraft:emerald")
  assert(saved.creditsPerItem == 1)
end

function tests.setup_can_be_cancelled_without_touching_configuration()
  local originalConfig = "return { casinoId = \"keep-me\" }"
  local files, answersUsed = runWizard("cashier", { "", "", "", "q" }, {
    input = "inventory",
    left = "modem",
    output = "inventory",
    vault = "inventory",
  }, originalConfig)
  assert(files["/casino/config.lua"] == originalConfig)
  assert(files["/casino/config.before-setup.lua"] == nil)
  assert(answersUsed == 4)
end

return tests
