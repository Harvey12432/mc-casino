local roulette = require("server.games.roulette")
local crash = require("server.games.crash")
local mines = require("server.games.mines")
local plinko = require("server.games.plinko")
local racing = require("server.games.horse_racing")
local poker = require("server.games.poker")
local craps = require("server.games.craps")
local coinFlip = require("server.games.coin_flip")

local tests = {}

local function withRandom(random, callback)
  local original = math.random
  math.random = random
  local ok, result = pcall(callback)
  math.random = original
  assert(ok, result)
  return result
end

function tests.roulette_supports_colours_and_straight_numbers()
  assert(roulette.validate({choice="red"}))
  assert(roulette.validate({choice=36}))
  assert(not roulette.validate({choice=37}))
  local state = withRandom(function() return 7 end,
    function() return roulette.create(10, {choice="red"}) end)
  assert(state.number == 7 and state.payout == 20)
end

function tests.crash_hides_point_until_round_is_over()
  local state = withRandom(function() return 500000 end,
    function() return crash.create(10) end)
  local view = crash.view({id="g",revision=1,state=state})
  assert(view.crashPoint == nil and view.phase == "running")
  state.startedAt = state.startedAt - 1000000
  crash.tick(state)
  assert(state.phase == "settled" and state.payout == 0)
end

function tests.mines_never_exposes_hidden_map_during_play()
  local state = withRandom(function(maximum) return maximum end,
    function() return mines.create(10, {mines=3}) end)
  local view = mines.view({id="g",revision=1,state=state})
  assert(view.mines == nil and #view.revealed == 0)
  local safe
  for position = 1, 25 do
    if not state.mines[tostring(position)] then safe = position break end
  end
  assert(mines.action(state, "reveal", {position=safe}))
  assert(state.revealedCount == 1)
end

function tests.plinko_uses_server_generated_path()
  local state = withRandom(function() return 1 end,
    function() return plinko.create(10) end)
  assert(#state.path == 8 and state.bin == 9 and state.payout == 100)
end

function tests.horse_racing_validates_selection()
  assert(not racing.validate({horse=6}))
  local state = withRandom(function() return 1 end,
    function() return racing.create(10, {horse=5}) end)
  assert(#state.order == 5 and state.winner >= 1 and state.winner <= 5)
end

function tests.horse_racing_pays_five_times_for_five_equal_horses()
  withRandom(function(maximum) return maximum end, function()
    local state = racing.create(10, { horse = 1 })
    assert(state.winner == 1)
    assert(state.outcome == "win")
    assert(state.payout == 50)
  end)
end

function tests.poker_evaluates_royal_flush()
  local outcome, multiplier = poker.evaluate({
    {rank="10",suit="S"},{rank="J",suit="S"},{rank="Q",suit="S"},
    {rank="K",suit="S"},{rank="A",suit="S"},
  })
  assert(outcome == "royal_flush" and multiplier == 250)
end

function tests.craps_come_out_seven_wins()
  local rolls = {3,4}
  local index = 0
  local state = withRandom(function()
    index=index+1
    return rolls[index]
  end, function() return craps.create(10) end)
  assert(state.phase == "settled" and state.payout == 20)
end

function tests.craps_history_is_bounded_during_a_long_round()
  local calls = 0
  local state = withRandom(function()
    calls = calls + 1
    if calls <= 2 then return 2 end
    return calls % 2 == 1 and 2 or 3
  end, function()
    local current = craps.create(10)
    for _ = 1, 30 do
      assert(craps.action(current, "roll"))
    end
    return current
  end)
  assert(state.phase == "point")
  assert(state.point == 4)
  assert(#state.history == 20)
  assert(state.history[#state.history].total == 5)
end

function tests.coin_flip_settles_on_server()
  local state = withRandom(function() return 1 end,
    function() return coinFlip.create(10, {choice="heads"}) end)
  assert(state.result == "heads" and state.payout == 20)
end

return tests
