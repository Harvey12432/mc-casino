local StateValidation = require("server.games.state_validation")
local blackjack = require("server.games.blackjack")
local slots = require("server.games.slots")
local roulette = require("server.games.roulette")
local crash = require("server.games.crash")
local mines = require("server.games.mines")
local plinko = require("server.games.plinko")
local horseRacing = require("server.games.horse_racing")
local poker = require("server.games.poker")
local craps = require("server.games.craps")
local coinFlip = require("server.games.coin_flip")

local tests = {}

local function assertValid(gameType, state)
  assert(StateValidation.valid(gameType, state), gameType .. " state was rejected")
end

function tests.every_game_engine_produces_a_valid_persisted_state()
  assertValid("slots", slots.spin(5))
  assertValid("blackjack", blackjack.create(5, {
    decks = 1,
    dealerHitsSoft17 = false,
    blackjackPayoutNumerator = 3,
    blackjackPayoutDenominator = 2,
  }))
  assertValid("roulette", roulette.create(5, { choice = "red" }))
  assertValid("crash", crash.create(5))
  assertValid("mines", mines.create(5, { mines = 3 }))
  assertValid("plinko", plinko.create(5))
  assertValid("horse_racing", horseRacing.create(5, { horse = 2 }))
  assertValid("poker", poker.create(5))
  assertValid("craps", craps.create(5))
  assertValid("coin_flip", coinFlip.create(5, { choice = "heads" }))
end

function tests.maximum_configured_blackjack_shoe_is_persistable()
  assertValid("blackjack", blackjack.create(5, {
    decks = 8,
    dealerHitsSoft17 = false,
    blackjackPayoutNumerator = 3,
    blackjackPayoutDenominator = 2,
  }))
end

function tests.per_game_required_fields_cannot_be_omitted()
  local states = {
    slots = slots.spin(5),
    blackjack = blackjack.create(5, {
      decks = 1,
      dealerHitsSoft17 = false,
      blackjackPayoutNumerator = 3,
      blackjackPayoutDenominator = 2,
    }),
    roulette = roulette.create(5, { choice = "red" }),
    crash = crash.create(5),
    mines = mines.create(5, { mines = 3 }),
    plinko = plinko.create(5),
    horse_racing = horseRacing.create(5, { horse = 2 }),
    poker = poker.create(5),
    craps = craps.create(5),
    coin_flip = coinFlip.create(5, { choice = "heads" }),
  }
  local required = {
    slots = "reels",
    blackjack = "shoe",
    roulette = "number",
    crash = "crashPoint",
    mines = "mines",
    plinko = "path",
    horse_racing = "order",
    poker = "hand",
    craps = "history",
    coin_flip = "result",
  }
  for gameType, state in pairs(states) do
    state[required[gameType]] = nil
    assert(
      not StateValidation.valid(gameType, state),
      gameType .. " accepted a state without " .. required[gameType]
    )
  end
end

function tests.every_game_engine_produces_a_valid_public_view()
  local states = {
    slots = { engine=slots, state=slots.spin(5) },
    blackjack = {
      engine=blackjack,
      state=blackjack.create(5, {
        decks = 1,
        dealerHitsSoft17 = false,
        blackjackPayoutNumerator = 3,
        blackjackPayoutDenominator = 2,
      }),
    },
    roulette = {
      engine=roulette,
      state=roulette.create(5, { choice = "red" }),
    },
    crash = { engine=crash, state=crash.create(5) },
    mines = { engine=mines, state=mines.create(5, { mines = 3 }) },
    plinko = { engine=plinko, state=plinko.create(5) },
    horse_racing = {
      engine=horseRacing,
      state=horseRacing.create(5, { horse = 2 }),
    },
    poker = { engine=poker, state=poker.create(5) },
    craps = { engine=craps, state=craps.create(5) },
    coin_flip = {
      engine=coinFlip,
      state=coinFlip.create(5, { choice = "heads" }),
    },
  }
  for gameType, fixture in pairs(states) do
    local view = fixture.engine.view({
      id = "game:" .. gameType,
      revision = 1,
      state = fixture.state,
    })
    assert(
      StateValidation.validView(gameType, view),
      gameType .. " public view was rejected"
    )
    view.payout = view.payout + 1
    assert(
      not StateValidation.validView(gameType, view),
      gameType .. " public view accepted a tampered payout"
    )
  end
end

function tests.tampered_payouts_are_rejected_for_every_game()
  local states = {
    slots = slots.spin(5),
    blackjack = blackjack.create(5, {
      decks = 1,
      dealerHitsSoft17 = false,
      blackjackPayoutNumerator = 3,
      blackjackPayoutDenominator = 2,
    }),
    roulette = roulette.create(5, { choice = "red" }),
    crash = crash.create(5),
    mines = mines.create(5, { mines = 3 }),
    plinko = plinko.create(5),
    horse_racing = horseRacing.create(5, { horse = 2 }),
    poker = poker.create(5),
    craps = craps.create(5),
    coin_flip = coinFlip.create(5, { choice = "heads" }),
  }
  for gameType, state in pairs(states) do
    state.payout = state.payout + 1
    assert(
      not StateValidation.valid(gameType, state),
      gameType .. " accepted a tampered payout"
    )
  end
end

function tests.legacy_slots_results_remain_readable_after_paytable_upgrade()
  local legacy = {
    phase = "settled",
    bet = 5,
    reels = { "cherry", "cherry", "lemon" },
    outcome = "win",
    payout = 10,
    jackpot = false,
  }
  assert(StateValidation.valid("slots", legacy))
  local view = {
    gameId = "game:legacy-slots",
    game = "slots",
    revision = 1,
    phase = "settled",
    bet = 5,
    reels = legacy.reels,
    outcome = legacy.outcome,
    payout = legacy.payout,
    jackpot = 0,
  }
  assert(StateValidation.validView("slots", view))
end

function tests.legacy_horse_results_remain_readable_after_paytable_upgrade()
  local legacy = {
    phase = "settled",
    bet = 10,
    selected = 1,
    order = { 1, 2, 3, 4, 5 },
    winner = 1,
    outcome = "win",
    payout = 40,
  }
  assert(StateValidation.valid("horse_racing", legacy))
  local view = {
    gameId = "game:legacy-horse",
    game = "horse_racing",
    revision = 1,
    phase = "settled",
    bet = 10,
    selected = 1,
    order = legacy.order,
    winner = 1,
    outcome = "win",
    payout = 40,
  }
  assert(StateValidation.validView("horse_racing", view))
end

function tests.balance_capped_payouts_preserve_gross_integrity()
  local originalRandom = math.random
  math.random = function() return 1 end
  local state = coinFlip.create(10, { choice = "heads" })
  math.random = originalRandom
  state.creditedPayout = 5
  state.payoutCapped = true
  assert(StateValidation.valid("coin_flip", state))

  local view = coinFlip.view({
    id = "game:capped-coin",
    revision = 1,
    state = state,
  })
  view.grossPayout = view.payout
  view.payout = state.creditedPayout
  view.payoutCapped = true
  assert(StateValidation.validView("coin_flip", view))

  view.grossPayout = 19
  assert(not StateValidation.validView("coin_flip", view))
end

return tests
