local plinko = {}
local multipliers = { 10, 3, 1.5, 0.7, 0.3, 0.7, 1.5, 3, 10 }

function plinko.validate() return true end

function plinko.create(bet)
  local path, bin = {}, 1
  for row = 1, 8 do
    local direction = math.random(0, 1)
    path[row] = direction == 0 and "L" or "R"
    bin = bin + direction
  end
  local multiplier = multipliers[bin]
  return {
    phase="settled", bet=bet, path=path, bin=bin, multiplier=multiplier,
    outcome=multiplier > 1 and "win" or (multiplier == 1 and "push" or "lose"),
    payout=math.floor(bet * multiplier),
  }
end

function plinko.view(game)
  local s = game.state
  return {
    gameId=game.id, game="plinko", revision=game.revision, phase=s.phase,
    bet=s.bet, path=s.path, bin=s.bin, multiplier=s.multiplier,
    outcome=s.outcome, payout=s.payout,
  }
end

return plinko
