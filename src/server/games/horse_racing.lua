local racing = {}

function racing.validate(options)
  local horse = options and tonumber(options.horse)
  return horse and horse == math.floor(horse) and horse >= 1 and horse <= 5
end

function racing.create(bet, options)
  local selected = tonumber(options.horse)
  local order = { 1, 2, 3, 4, 5 }
  for index = #order, 2, -1 do
    local other = math.random(index)
    order[index], order[other] = order[other], order[index]
  end
  local won = order[1] == selected
  return {
    rulesVersion=2,
    phase="settled", bet=bet, selected=selected, order=order, winner=order[1],
    outcome=won and "win" or "lose", payout=won and bet * 5 or 0,
  }
end

function racing.view(game)
  local s = game.state
  return {
    gameId=game.id, game="horse_racing", revision=game.revision, phase=s.phase,
    bet=s.bet, selected=s.selected, order=s.order, winner=s.winner,
    outcome=s.outcome, payout=s.payout, rulesVersion=s.rulesVersion,
  }
end

return racing
