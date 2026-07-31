-- Guided configuration for every MC Casino computer role.
-- Run without arguments after installation; /casino/role supplies the role.
local role = ({ ... })[1]
local configPath = "/casino/config.lua"
local backupPath = "/casino/config.before-setup.lua"

local validRoles = {
  server = true, admin = true, blackjack = true, cashier = true,
  coin_flip = true, craps = true, crash = true, horse_racing = true,
  leaderboard = true, mines = true, plinko = true, poker = true,
  roulette = true, slots = true,
}

local function readFile(path)
  local handle = fs.open(path, "r")
  if not handle then return nil end
  local contents = handle.readAll()
  handle.close()
  return contents
end

if not role and fs.exists("/casino/role") then role = readFile("/casino/role") end
if not validRoles[role] then
  error("Unknown casino role; reinstall this computer with a valid role", 0)
end

local defaults = {
  casinoId = "main-floor",
  serverHostname = "mc-casino-main",
  authorizedCashierIds = {},
  authorizedAdminIds = {},
  cashierInput = nil,
  cashierVault = nil,
  cashierOutput = nil,
  currencyItem = "minecraft:emerald",
  creditsPerItem = 1,
  minimumBet = 5,
  maximumBet = 500,
  maximumBalance = 1000000000,
  blackjackDecks = 6,
  dealerHitsSoft17 = false,
  monitorSide = "top",
  acceptancePlayerId = "casino_test",
}

local values = {}
for key, value in pairs(defaults) do values[key] = value end
local loadWarning
if fs.exists(configPath) then
  local contents = readFile(configPath)
  local chunk, compileError = load(contents or "", "@" .. configPath, "t", {})
  if chunk then
    local loaded, result = pcall(chunk)
    if loaded and type(result) == "table" then
      for key, value in pairs(result) do values[key] = value end
    else
      loadWarning = "Existing configuration could not be read; defaults are shown."
    end
  else
    loadWarning = "Existing configuration has invalid Lua: " .. tostring(compileError)
  end
end

local colourTerminal = term.isColor and term.isColor()
local function foreground(colour)
  if colourTerminal then term.setTextColor(colour) end
end
local function background(colour)
  if colourTerminal then term.setBackgroundColor(colour) end
end
local function resetTerminal()
  background(colors.black)
  foreground(colors.white)
  term.clear()
  term.setCursorPos(1, 1)
end
local function writeLine(text, colour)
  foreground(colour or colors.white)
  print(tostring(text or ""))
end
local function valueLabel(value)
  if value == nil then return "not set" end
  if type(value) == "boolean" then return value and "yes" or "no" end
  if type(value) == "table" then
    if #value == 0 then return "none" end
    local shown = {}
    for index, item in ipairs(value) do shown[index] = tostring(item) end
    return table.concat(shown, ", ")
  end
  return tostring(value)
end

local totalSteps = role == "server" and 12
  or (role == "cashier" and 8
    or (role == "leaderboard" and 4 or 3))
local currentStep = 0

local function drawQuestion(title, hint, current, choices, validationError)
  resetTerminal()
  foreground(colors.lime)
  print("MC CASINO SETUP")
  foreground(colors.lightGray)
  print(("%s  |  STEP %d OF %d"):format(role:upper(), currentStep, totalSteps))
  local filled = math.floor((currentStep / totalSteps) * 24)
  foreground(colors.green)
  print("[" .. string.rep("=", filled) .. string.rep(" ", 24 - filled) .. "]")
  print("")
  writeLine(title, colors.yellow)
  writeLine(hint, colors.lightGray)
  print("")
  writeLine("Current: " .. valueLabel(current), colors.white)
  if choices and #choices > 0 then
    foreground(colors.cyan)
    for index = 1, math.min(#choices, 5) do
      print(("  %d. %s"):format(index, choices[index]))
    end
  end
  if validationError then
    print("")
    writeLine(validationError, colors.red)
  end
  print("")
  writeLine("Enter a value, leave blank to keep it, or Q to cancel.", colors.lightGray)
  foreground(colors.white)
  write("> ")
end

  local cancelled = false
  local function prompt(title, hint, current, parser, validator, choices)
    if cancelled then
      return current
    end

    currentStep = currentStep + 1
  local validationError
  while true do
    drawQuestion(title, hint, current, choices, validationError)
    local entered = read()
    if entered:lower() == "q" then
      cancelled = true
      return current
    end
    local candidate, parseError
    if entered == "" then
      candidate = current
    else
      candidate, parseError = parser(entered)
    end
    if not parseError and validator then
      local valid, message = validator(candidate)
      if not valid then parseError = message end
    end
    if not parseError then return candidate end
    validationError = parseError
  end
end

local function stringParser(value) return value end
local function nonEmpty(maximum)
  return function(value)
    if type(value) ~= "string" or value == "" then
      return false, "This value cannot be empty."
    end
    if #value > maximum then
      return false, "Keep this value within " .. maximum .. " characters."
    end
    return true
  end
end
local function integerParser(value)
  local number = tonumber(value)
  if not number or number ~= math.floor(number) then
    return nil, "Enter a whole number."
  end
  return number
end
local function integerRange(minimum, maximum)
  return function(value)
    if type(value) ~= "number" or value < minimum or value > maximum then
      return false, ("Enter a number from %s to %s."):format(minimum, maximum)
    end
    return true
  end
end
local function booleanParser(value)
  local normalized = value:lower()
  if normalized == "y" or normalized == "yes" or normalized == "true" then
    return true
  elseif normalized == "n" or normalized == "no" or normalized == "false" then
    return false
  end
  return nil, "Enter yes or no."
end
local function idsParser(value)
  if value == "-" or value:lower() == "none" then return {} end
  local result, seen = {}, {}
  for token in value:gmatch("[^,%s]+") do
    local id = tonumber(token)
    if not id or id < 0 or id ~= math.floor(id) then
      return nil, "Use whole computer IDs separated by commas."
    end
    if not seen[id] then
      result[#result + 1], seen[id] = id, true
    end
  end
  if #result == 0 then
    return nil, "Enter IDs separated by commas, or '-' for none yet."
  end
  table.sort(result)
  return result
end

local function hasPeripheralType(name, wanted)
  if peripheral.hasType then
    local ok, result = pcall(peripheral.hasType, name, wanted)
    if ok and result then return true end
  end
  local ok, first = pcall(peripheral.getType, name)
  return ok and first == wanted
end
local function isInventory(name)
  if hasPeripheralType(name, "inventory") then return true end
  local ok, wrapped = pcall(peripheral.wrap, name)
  return ok and wrapped
    and type(wrapped.list) == "function"
    and type(wrapped.pushItems) == "function"
end
local function discover(predicate)
  local result = {}
  for _, name in ipairs(peripheral.getNames()) do
    if predicate(name) then result[#result + 1] = name end
  end
  table.sort(result)
  return result
end
local function peripheralPrompt(title, hint, current, predicate, excluded)
  local choices = discover(predicate)
  local recommended = current
  if not recommended or not predicate(recommended) then
    recommended = nil
    for _, name in ipairs(choices) do
      if not excluded or not excluded[name] then recommended = name break end
    end
  end
  local function parser(value)
    local index = tonumber(value)
    if index and index == math.floor(index) and choices[index] then
      return choices[index]
    end
    return value
  end
  local function validator(value)
    if type(value) ~= "string" or value == "" or not predicate(value) then
      return false, "Choose a detected compatible peripheral."
    end
    if excluded and excluded[value] then
      return false, "That peripheral is already used for another purpose."
    end
    return true
  end
  return prompt(title, hint, recommended, parser, validator, choices)
end

values.casinoId = prompt(
  "Casino identity",
  "Use the same short identity on every casino computer.",
  values.casinoId,
  stringParser,
  nonEmpty(64)
)
if not cancelled then
  values.serverHostname = prompt(
    "Server network name",
    "Clients discover the central server using this shared name.",
    values.serverHostname,
    stringParser,
    nonEmpty(128)
  )
end
if not cancelled then
  values.modemSide = peripheralPrompt(
    "Network modem",
    "Choose the wired or wireless modem attached to this computer.",
    values.modemSide,
    function(name) return hasPeripheralType(name, "modem") end
  )
end

if role == "server" and not cancelled then
  values.authorizedCashierIds = prompt(
    "Trusted cashier computer IDs",
    "Enter IDs separated by commas, or '-' to configure them later.",
    values.authorizedCashierIds,
    idsParser
  )
  values.authorizedAdminIds = prompt(
    "Trusted administrator computer IDs",
    "Enter IDs separated by commas, or '-' to configure them later.",
    values.authorizedAdminIds,
    idsParser
  )
  values.currencyItem = prompt(
    "Casino currency item",
    "Use its full Minecraft identifier, for example minecraft:emerald.",
    values.currencyItem,
    stringParser,
    nonEmpty(128)
  )
  values.creditsPerItem = prompt(
    "Credits per deposited item",
    "One is simplest for the first live test.",
    values.creditsPerItem,
    integerParser,
    integerRange(1, 1000000)
  )
  values.minimumBet = prompt(
    "Minimum bet",
    "The smallest wager accepted by every game.",
    values.minimumBet,
    integerParser,
    integerRange(1, 1000000000)
  )
  values.maximumBet = prompt(
    "Maximum bet",
    "Must be at least the minimum bet.",
    values.maximumBet,
    integerParser,
    function(value)
      if type(value) ~= "number" or value < values.minimumBet
        or value > 1000000000
      then
        return false, "Enter a whole number at least equal to the minimum bet."
      end
      return true
    end
  )
  values.maximumBalance = prompt(
    "Maximum player balance",
    "Wins above this safety ceiling are visibly capped.",
    values.maximumBalance,
    integerParser,
    integerRange(1, 1000000000)
  )
  values.blackjackDecks = prompt(
    "Blackjack shoe size",
    "Choose 1-8 decks; six is the casino default.",
    values.blackjackDecks,
    integerParser,
    integerRange(1, 8)
  )
  values.dealerHitsSoft17 = prompt(
    "Dealer hits soft 17?",
    "No uses the documented default rule. Enter yes or no.",
    values.dealerHitsSoft17,
    booleanParser,
    function(value) return type(value) == "boolean", "Enter yes or no." end
  )
elseif role == "cashier" and not cancelled then
  local used = {}
  values.cashierInput = peripheralPrompt(
    "Deposit input inventory",
    "Players place currency items in this inventory.",
    values.cashierInput,
    isInventory,
    used
  )
  if not cancelled and values.cashierInput then
    used[values.cashierInput] = true
  end
  values.cashierVault = peripheralPrompt(
    "Secure vault inventory",
    "Deposited currency is stored here.",
    values.cashierVault,
    isInventory,
    used
  )
  if not cancelled and values.cashierVault then
    used[values.cashierVault] = true
  end
  values.cashierOutput = peripheralPrompt(
    "Withdrawal output inventory",
    "Player withdrawals are delivered here.",
    values.cashierOutput,
    isInventory,
    used
  )
  values.currencyItem = prompt(
    "Casino currency item",
    "This must exactly match the central server.",
    values.currencyItem,
    stringParser,
    nonEmpty(128)
  )
  values.creditsPerItem = prompt(
    "Credits per deposited item",
    "This must exactly match the central server.",
    values.creditsPerItem,
    integerParser,
    integerRange(1, 1000000)
  )
elseif role == "leaderboard" and not cancelled then
  values.monitorSide = peripheralPrompt(
    "Leaderboard monitor",
    "Choose the attached advanced monitor wall.",
    values.monitorSide,
    function(name) return hasPeripheralType(name, "monitor") end
  )
end

local summaryKeys = {
  { "casinoId", "Casino" },
  { "serverHostname", "Server" },
  { "modemSide", "Modem" },
}
if role == "server" then
  summaryKeys[#summaryKeys + 1] = { "authorizedCashierIds", "Cashiers" }
  summaryKeys[#summaryKeys + 1] = { "authorizedAdminIds", "Admins" }
  summaryKeys[#summaryKeys + 1] = { "currencyItem", "Currency" }
  summaryKeys[#summaryKeys + 1] = { "creditsPerItem", "Rate" }
  summaryKeys[#summaryKeys + 1] = { "minimumBet", "Min bet" }
  summaryKeys[#summaryKeys + 1] = { "maximumBet", "Max bet" }
  summaryKeys[#summaryKeys + 1] = { "maximumBalance", "Balance cap" }
  summaryKeys[#summaryKeys + 1] = { "blackjackDecks", "BJ decks" }
  summaryKeys[#summaryKeys + 1] = { "dealerHitsSoft17", "Hit soft 17" }
elseif role == "cashier" then
  summaryKeys[#summaryKeys + 1] = { "cashierInput", "Input" }
  summaryKeys[#summaryKeys + 1] = { "cashierVault", "Vault" }
  summaryKeys[#summaryKeys + 1] = { "cashierOutput", "Output" }
  summaryKeys[#summaryKeys + 1] = { "currencyItem", "Currency" }
  summaryKeys[#summaryKeys + 1] = { "creditsPerItem", "Rate" }
elseif role == "leaderboard" then
  summaryKeys[#summaryKeys + 1] = { "monitorSide", "Monitor" }
end

if cancelled then
  resetTerminal()
  writeLine("SETUP CANCELLED", colors.yellow)
  print("No configuration changes were saved.")
  return
end

resetTerminal()
writeLine("REVIEW CONFIGURATION", colors.lime)
writeLine(role:upper() .. " is ready to save", colors.lightGray)
print("")
for _, entry in ipairs(summaryKeys) do
  print(("%-13s %s"):format(entry[2] .. ":", valueLabel(values[entry[1]])))
end
if loadWarning then
  print("")
  writeLine(loadWarning, colors.orange)
end
print("")
writeLine("Save these settings? [Y/n]", colors.yellow)
foreground(colors.white)
write("> ")
local confirmation = read():lower()
if confirmation == "n" or confirmation == "no" or confirmation == "q" then
  resetTerminal()
  writeLine("SETUP CANCELLED", colors.yellow)
  print("No configuration changes were saved.")
  return
end

local function serialize(value, indent, seen)
  local kind = type(value)
  if kind == "string" then return string.format("%q", value) end
  if kind == "number" or kind == "boolean" then return tostring(value) end
  if kind ~= "table" then error("Unsupported configuration value: " .. kind) end
  seen = seen or {}
  if seen[value] then error("Configuration tables cannot contain cycles") end
  seen[value] = true
  indent = indent or 0
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(first, second) return tostring(first) < tostring(second) end)
  local lines = { "{" }
  for _, key in ipairs(keys) do
    local keyText = type(key) == "string" and key:match("^[A-Za-z_][A-Za-z0-9_]*$")
      and key or ("[" .. serialize(key, indent + 1, seen) .. "]")
    lines[#lines + 1] = string.rep("  ", indent + 1)
      .. keyText .. " = " .. serialize(value[key], indent + 1, seen) .. ","
  end
  lines[#lines + 1] = string.rep("  ", indent) .. "}"
  seen[value] = nil
  return table.concat(lines, "\n")
end

local contents = "-- Generated by /casino/setup.lua for " .. role .. ".\nreturn "
  .. serialize(values) .. "\n"
local verifiedChunk, verifyError = load(contents, "@config.new", "t", {})
if not verifiedChunk then error("Generated configuration is invalid: " .. verifyError) end
local verified, verifiedValues = pcall(verifiedChunk)
if not verified or type(verifiedValues) ~= "table" then
  error("Generated configuration did not return a table")
end

local temporaryPath = configPath .. ".new"
if fs.exists(temporaryPath) then fs.delete(temporaryPath) end
local output = assert(fs.open(temporaryPath, "w"), "Cannot write " .. temporaryPath)
output.write(contents)
output.close()

if fs.exists(backupPath) then fs.delete(backupPath) end
if fs.exists(configPath) then fs.copy(configPath, backupPath) end
if fs.exists(configPath) then fs.delete(configPath) end
local moved, moveError = pcall(fs.move, temporaryPath, configPath)
if not moved then
  if fs.exists(backupPath) and not fs.exists(configPath) then
    fs.copy(backupPath, configPath)
  end
  error("Could not activate the new configuration: " .. tostring(moveError), 0)
end

resetTerminal()
writeLine("CONFIGURATION SAVED", colors.lime)
print("")
print("Role: " .. role)
print("Path: " .. configPath)
if fs.exists(backupPath) then print("Previous settings: " .. backupPath) end
print("")
writeLine("Next: run /casino/dev/preflight.lua " .. role, colors.yellow)
writeLine("Then type reboot when every check passes.", colors.white)
