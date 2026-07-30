local slots = {}

local stops = {
  "cherry", "cherry", "cherry", "cherry",
  "lemon", "lemon", "lemon",
  "bell", "bell",
  "diamond",
  "seven",
}

local multipliers = {
  cherry = 2,
  lemon = 3,
  bell = 5,
  diamond = 8,
  seven = 15,
}

function slots.jackpotContribution(bet, rulesVersion)
  if rulesVersion == nil then
    return math.max(1, math.floor(bet / 20))
  end
  assert(rulesVersion == 2, "Unsupported Slots rules version")
  -- Reserve up to 20% of each bet for the progressive. The minimum contribution
  -- keeps small bets visibly moving the jackpot; rounding down prevents wagers
  -- just above a five-credit boundary from becoming player-positive.
  return math.max(1, math.floor(bet / 5))
end

function slots.spin(bet)
  local reels = {}
  for index = 1, 3 do
    reels[index] = stops[math.random(#stops)]
  end

  local payout = 0
  local outcome = "lose"
  local jackpot = false
  if reels[1] == reels[2] and reels[2] == reels[3] then
    payout = bet * multipliers[reels[1]]
    outcome = "win"
    jackpot = reels[1] == "seven"
  elseif reels[1] == reels[2]
    or reels[1] == reels[3]
    or reels[2] == reels[3]
  then
    payout = bet
    outcome = "push"
  end

  return {
    rulesVersion = 2,
    phase = "settled",
    bet = bet,
    reels = reels,
    outcome = outcome,
    payout = payout,
    jackpot = jackpot,
  }
end

function slots.view(game)
  return {
    gameId = game.id,
    game = "slots",
    revision = game.revision,
    phase = "settled",
    bet = game.state.bet,
    reels = game.state.reels,
    outcome = game.state.outcome,
    payout = game.state.payout,
    jackpot = game.state.jackpotAmount or 0,
    rulesVersion = game.state.rulesVersion,
  }
end

return slots
