-- Run from an installed, server-authorised admin computer:
-- disk/casino/dev/acceptance.lua
shell.setDir("/casino")

local Client = require("client.shared.client")
local protocol = require("shared.protocol")
local config = require("shared.config")

local client = Client.new()
assert(client:connect(), "Casino server was not discovered")

local session, loginError = client:login(config.acceptancePlayerId)
assert(session, loginError)
assert(session.role == "admin", "This computer is not authorised as admin")

local function request(messageType, payload)
  local result, requestError = client:request(messageType, payload)
  assert(result, requestError)
  return result
end

local function action(game, name, extra)
  local payload = extra or {}
  payload.gameId = game.gameId
  payload.action = name
  payload.expectedRevision = game.revision
  return request(protocol.types.GAME_ACTION, payload)
end

local account = request(protocol.types.ACCOUNT_VIEW, {})
local initialBalance = account.player.balance
local bet = config.minimumBet
local requiredBalance = bet * 20
local topUp = math.max(0, requiredBalance - initialBalance)
if topUp > 0 then
  request(protocol.types.ADMIN_COMMAND, {
    command = "adjust",
    player = account.player.id,
    amount = topUp,
  })
end

local checked = {}
local function create(gameType, options)
  local game = request(protocol.types.GAME_CREATE, {
    game = gameType,
    bet = bet,
    options = options or {},
    acceptanceTest = true,
  })
  assert(game.game == gameType, "Server returned the wrong game")
  checked[gameType] = true
  return game
end

assert(create("slots").phase == "settled", "Slots did not settle")
local blackjack = create("blackjack")
if blackjack.phase ~= "settled" then blackjack = action(blackjack, "stand") end
assert(blackjack.phase == "settled", "Blackjack did not settle")
assert(create("roulette", { choice = "red" }).phase == "settled",
  "Roulette did not settle")
local crash = create("crash")
if crash.phase ~= "settled" then crash = action(crash, "cashout") end
assert(crash.phase == "settled", "Crash did not settle")
local mines = create("mines", { mines = 3 })
if mines.phase ~= "settled" then mines = action(mines, "reveal", { position = 1 }) end
if mines.phase ~= "settled" then mines = action(mines, "cashout") end
assert(mines.phase == "settled", "Mines did not settle")
assert(create("plinko").phase == "settled", "Plinko did not settle")
assert(create("horse_racing", { horse = 1 }).phase == "settled",
  "Horse Racing did not settle")
local poker = create("poker")
if poker.phase ~= "settled" then poker = action(poker, "draw", { held = {} }) end
assert(poker.phase == "settled", "Poker did not settle")
local craps = create("craps")
local rolls = 0
while craps.phase ~= "settled" and rolls < 100 do
  craps = action(craps, "roll")
  rolls = rolls + 1
end
assert(craps.phase == "settled", "Craps did not settle within 100 rolls")
assert(create("coin_flip", { choice = "heads" }).phase == "settled",
  "Coin Flip did not settle")

for _, gameType in ipairs({
  "slots", "blackjack", "roulette", "crash", "mines", "plinko",
  "horse_racing", "poker", "craps", "coin_flip",
}) do
  assert(checked[gameType], gameType .. " was not checked")
end

local after = request(protocol.types.ACCOUNT_VIEW, {})
local correction = initialBalance - after.player.balance
if correction ~= 0 then
  request(protocol.types.ADMIN_COMMAND, {
    command = "adjust",
    player = account.player.id,
    amount = correction,
  })
end

local summary = request(protocol.types.ADMIN_COMMAND, { command = "summary" })
assert(type(summary.houseProfit) == "number", "House profit was not returned")
assert(type(summary.jackpot) == "number", "Jackpot was not returned")

print("MC Casino in-world acceptance passed")
print("Server discovery and admin session: ok")
print("Central balance ledger and restoration: ok")
print("All ten games: ok")
print("Admin summary: ok")
