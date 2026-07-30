local slots = require("server.games.slots")

local tests = {}

local function withRandom(values, callback)
  local originalRandom = math.random
  local index = 0
  math.random = function()
    index = index + 1
    return values[index]
  end
  local ok, result = pcall(callback)
  math.random = originalRandom
  assert(ok, result)
  return result
end

function tests.three_sevens_win_and_trigger_jackpot()
  local originalRandom = math.random
  math.random = function() return 11 end
  local ok, result = pcall(slots.spin, 5)
  math.random = originalRandom
  assert(ok, result)
  assert(result.reels[1] == "seven")
  assert(result.reels[2] == "seven")
  assert(result.reels[3] == "seven")
  assert(result.payout == 75)
  assert(result.jackpot == true)
end

function tests.non_matching_reels_lose()
  local originalRandom = math.random
  local values = { 1, 5, 8 }
  local index = 0
  math.random = function()
    index = index + 1
    return values[index]
  end
  local ok, result = pcall(slots.spin, 5)
  math.random = originalRandom
  assert(ok, result)
  assert(result.payout == 0)
  assert(result.outcome == "lose")
end

function tests.a_pair_returns_the_bet_without_printing_a_profit()
  withRandom({ 1, 1, 5 }, function()
    local result = slots.spin(10)
    assert(result.outcome == "push")
    assert(result.payout == 10)
  end)
end

function tests.slots_total_expected_return_stays_below_one()
  local originalRandom = math.random
  local totalPayout = 0
  local ok, testError = pcall(function()
    for first = 1, 11 do
      for second = 1, 11 do
        for third = 1, 11 do
          local values = { first, second, third }
          local index = 0
          math.random = function()
            index = index + 1
            return values[index]
          end
          totalPayout = totalPayout + slots.spin(100).payout
        end
      end
    end
  end)
  math.random = originalRandom
  assert(ok, testError)

  local baseReturn = totalPayout / (11 ^ 3 * 100)
  local totalReturn = baseReturn + slots.jackpotContribution(100, 2) / 100
  assert(baseReturn > 0.74 and baseReturn < 0.75)
  assert(totalReturn > 0.94 and totalReturn < 0.95)
  for bet = 5, 500 do
    local returnAtBet = baseReturn + slots.jackpotContribution(bet, 2) / bet
    assert(returnAtBet < 0.95, "Slots became player-positive at bet " .. bet)
  end
end

return tests
