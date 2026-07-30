-- Shared defaults. /casino/config.lua may override values per computer.
local config = {
  casinoId = "main-floor",
  protocol = "mc-casino.v1",
  basaltVersion = "2.5+a01ea6d577c92fcf76b5689f89eaf2920d011b82",
  serverHostname = "mc-casino-main",
  serverId = nil,
  requestTimeout = 3,
  requestRetries = 2,
  sessionTimeout = 3600,
  startingBalance = 0,
  maximumBalance = 1000000000,
  acceptancePlayerId = "casino_test",
  minimumBet = 5,
  maximumBet = 500,
  blackjackDecks = 6,
  dealerHitsSoft17 = false,
  currencyItem = "minecraft:emerald",
  creditsPerItem = 1,
  monitorSide = "top",
  modemSide = nil,
  authorizedCashierIds = {},
  authorizedAdminIds = {},
  cashierInput = nil,
  cashierVault = nil,
  cashierOutput = nil,
}

if fs and fs.exists("/casino/config.lua") then
  local overrides = dofile("/casino/config.lua")
  assert(type(overrides) == "table", "/casino/config.lua must return a table")
  for key, value in pairs(overrides) do
    config[key] = value
  end
end

local function positiveInteger(value)
  return type(value) == "number"
    and value > 0
    and value < math.huge
    and value == math.floor(value)
end

local function nonNegativeInteger(value)
  return type(value) == "number"
    and value >= 0
    and value < math.huge
    and value == math.floor(value)
end

local function validComputerIds(values)
  if type(values) ~= "table" then return false end
  for _, value in ipairs(values) do
    if not nonNegativeInteger(value) then return false end
  end
  return true
end

assert(
  type(config.casinoId) == "string"
    and #config.casinoId >= 1
    and #config.casinoId <= 64,
  "casinoId must contain 1-64 characters"
)
assert(
  type(config.protocol) == "string"
    and #config.protocol >= 1
    and #config.protocol <= 64,
  "protocol must contain 1-64 characters"
)
assert(
  type(config.serverHostname) == "string"
    and #config.serverHostname >= 1
    and #config.serverHostname <= 128,
  "serverHostname must contain 1-128 characters"
)
assert(
  config.serverId == nil or nonNegativeInteger(config.serverId),
  "serverId must be nil or a whole non-negative computer ID"
)
assert(positiveInteger(config.minimumBet), "minimumBet must be a positive integer")
assert(positiveInteger(config.maximumBet), "maximumBet must be a positive integer")
assert(config.maximumBet >= config.minimumBet, "maximumBet must be >= minimumBet")
assert(positiveInteger(config.creditsPerItem), "creditsPerItem must be a positive integer")
assert(
  type(config.currencyItem) == "string"
    and #config.currencyItem >= 1
    and #config.currencyItem <= 128,
  "currencyItem must contain 1-128 characters"
)
assert(
  type(config.requestTimeout) == "number"
    and config.requestTimeout == config.requestTimeout
    and config.requestTimeout > 0
    and config.requestTimeout < math.huge,
  "requestTimeout must be a finite positive number"
)
assert(nonNegativeInteger(config.requestRetries), "requestRetries must be a non-negative integer")
assert(positiveInteger(config.sessionTimeout), "sessionTimeout must be a positive integer")
assert(
  positiveInteger(config.blackjackDecks) and config.blackjackDecks <= 8,
  "blackjackDecks must be a whole number from 1 to 8"
)
assert(
  type(config.dealerHitsSoft17) == "boolean",
  "dealerHitsSoft17 must be true or false"
)
assert(nonNegativeInteger(config.startingBalance), "startingBalance must be a non-negative integer")
assert(positiveInteger(config.maximumBalance), "maximumBalance must be a positive integer")
assert(
  config.startingBalance <= config.maximumBalance,
  "startingBalance must not exceed maximumBalance"
)
assert(
  type(config.acceptancePlayerId) == "string"
    and #config.acceptancePlayerId <= 32
    and config.acceptancePlayerId:match("^[A-Za-z0-9_]+$"),
  "acceptancePlayerId must contain only letters, numbers, or underscore"
)
assert(
  validComputerIds(config.authorizedCashierIds),
  "authorizedCashierIds must contain whole non-negative computer IDs"
)
assert(
  validComputerIds(config.authorizedAdminIds),
  "authorizedAdminIds must contain whole non-negative computer IDs"
)
assert(
  config.modemSide == nil or type(config.modemSide) == "string",
  "modemSide must be nil or a peripheral name"
)
assert(
  type(config.monitorSide) == "string" and config.monitorSide ~= "",
  "monitorSide must be a peripheral name"
)
for _, key in ipairs({ "cashierInput", "cashierVault", "cashierOutput" }) do
  assert(
    config[key] == nil or (type(config[key]) == "string" and config[key] ~= ""),
    key .. " must be nil or a peripheral name"
  )
end

return config
