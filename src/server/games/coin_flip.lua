local coinFlip = {}

function coinFlip.validate(options)
  return options and (options.choice == "heads" or options.choice == "tails")
end

function coinFlip.create(bet, options)
  local result = math.random(2) == 1 and "heads" or "tails"
  local won = result == options.choice
  return {
    phase="settled", bet=bet, choice=options.choice, result=result,
    outcome=won and "win" or "lose", payout=won and bet * 2 or 0,
  }
end

function coinFlip.view(game)
  local s = game.state
  return {
    gameId=game.id, game="coin_flip", revision=game.revision, phase=s.phase,
    bet=s.bet, choice=s.choice, result=s.result, outcome=s.outcome, payout=s.payout,
  }
end

return coinFlip
