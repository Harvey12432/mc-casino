-- Run after installation:
-- disk/casino/dev/preflight.lua <server|game-role|cashier|leaderboard|admin>
local role = ({ ... })[1]
local validRoles = {
  server = true,
  blackjack = true,
  slots = true,
  cashier = true,
  leaderboard = true,
  admin = true,
  roulette = true,
  crash = true,
  mines = true,
  plinko = true,
  horse_racing = true,
  poker = true,
  craps = true,
  coin_flip = true,
}
if not validRoles[role] then
  error("Usage: preflight <server|game-role|cashier|leaderboard|admin>")
end

shell.setDir("/casino")
local config = require("shared.config")

local failures = 0
local warnings = 0

local function pass(message)
  print("[PASS] " .. message)
end

local function fail(message)
  failures = failures + 1
  printError("[FAIL] " .. message)
end

local function warn(message)
  warnings = warnings + 1
  print("[WARN] " .. message)
end

local modemName = config.modemSide
if modemName then
  if peripheral.getType(modemName) == "modem" then
    pass("Configured modem found at " .. modemName)
  else
    fail("Configured modem is missing at " .. tostring(modemName))
  end
else
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      modemName = name
      break
    end
  end
  if modemName then
    pass("Modem found at " .. modemName)
  else
    fail("No modem is attached")
  end
end

if role == "server" then
  for _, name in ipairs({
    "players.json",
    "transactions.json",
    "jackpots.json",
    "games.json",
    "system.json",
  }) do
    local path = "/casino/data/" .. name
    if fs.exists(path) then pass(path .. " exists") else fail(path .. " is missing") end
  end
  if #config.authorizedCashierIds == 0 then
    warn("No cashier computer IDs are authorised")
  else
    pass("Cashier computer IDs configured")
  end
  if #config.authorizedAdminIds == 0 then
    warn("No admin computer IDs are authorised")
  else
    pass("Admin computer IDs configured")
  end
else
  if fs.exists("/casino/basalt.lua") then
    local expected = config.basaltVersion
    local installed
    if fs.exists("/casino/basalt.version") then
      local versionFile = fs.open("/casino/basalt.version", "r")
      if versionFile then
        installed = versionFile.readAll()
        versionFile.close()
      end
    end
    local size = fs.getSize("/casino/basalt.lua")
    if installed == expected and size == 277062 then
      pass("Pinned Basalt " .. expected .. " is installed and complete")
    else
      fail(
        "Basalt version or size mismatch; rerun the terminal installer"
      )
    end
  else
    fail("/casino/basalt.lua is missing")
  end
  if role ~= "leaderboard" then
    local width, height = term.getSize()
    if width >= 51 and height >= 19 then
      pass(("Terminal size is %dx%d"):format(width, height))
    else
      fail(
        ("Terminal is %dx%d; casino clients require at least 51x19")
          :format(width, height)
      )
    end
    if term.isColor and term.isColor() then
      pass("Advanced colour terminal detected")
    else
      fail("An advanced colour computer is required")
    end
  end
  if modemName then
    rednet.open(modemName)
    local serverId = config.serverId
      or rednet.lookup(config.protocol, config.serverHostname)
    if serverId then
      pass("Casino server discovered as computer " .. serverId)
      local Client = require("client.shared.client")
      local client = Client.new()
      local connected, connectError = client:connect()
      if connected then
        pass("Casino server handshake completed")
        if role == "cashier" then
          local server = client.serverInfo or {}
          if server.currencyItem == config.currencyItem
            and server.creditsPerItem == config.creditsPerItem
          then
            pass("Cashier currency matches the server")
          else
            fail(
              "Cashier currency mismatch; server uses "
                .. tostring(server.currencyItem)
                .. " at "
                .. tostring(server.creditsPerItem)
                .. " credit(s) per item"
            )
          end
        end
      else
        fail("Casino server handshake failed: " .. tostring(connectError))
      end
    else
      fail("Casino server could not be discovered")
    end
  end
end

if role == "cashier" then
  for _, entry in ipairs({
    { key = "cashierInput", value = config.cashierInput },
    { key = "cashierVault", value = config.cashierVault },
    { key = "cashierOutput", value = config.cashierOutput },
  }) do
    local wrapped = entry.value and peripheral.wrap(entry.value) or nil
    if wrapped
      and type(wrapped.list) == "function"
      and type(wrapped.pushItems) == "function"
    then
      pass(entry.key .. " inventory found at " .. entry.value)
    else
      fail(entry.key .. " is missing or not an inventory")
    end
  end
end

if role == "leaderboard" then
  local monitor = peripheral.wrap(config.monitorSide)
  if monitor and peripheral.getType(config.monitorSide) == "monitor" then
    pass("Leaderboard monitor found at " .. config.monitorSide)
    local width, height = monitor.getSize()
    if width >= 30 and height >= 18 then
      pass(("Leaderboard monitor size is %dx%d"):format(width, height))
    else
      fail(
        ("Leaderboard monitor is %dx%d; resize it to at least 30x18")
          :format(width, height)
      )
    end
    if monitor.isColor and monitor.isColor() then
      pass("Advanced colour monitor detected")
    else
      fail("An advanced colour monitor is required")
    end
  else
    fail("Leaderboard monitor is missing at " .. tostring(config.monitorSide))
  end
end

print(("%d failure(s), %d warning(s)"):format(failures, warnings))
if failures > 0 then error("Casino preflight failed", 0) end
print("Casino " .. role .. " preflight passed")
