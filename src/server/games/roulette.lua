local roulette = {}

local red = {
  [1]=true,[3]=true,[5]=true,[7]=true,[9]=true,[12]=true,[14]=true,[16]=true,
  [18]=true,[19]=true,[21]=true,[23]=true,[25]=true,[27]=true,[30]=true,
  [32]=true,[34]=true,[36]=true,
}

function roulette.validate(options)
  local choice = options and options.choice
  if type(choice) == "number" then
    return choice == math.floor(choice) and choice >= 0 and choice <= 36
  end
  return choice == "red" or choice == "black" or choice == "odd"
    or choice == "even" or choice == "low" or choice == "high"
end

function roulette.create(bet, options)
  local number = math.random(0, 36)
  local choice = options.choice
  local won = choice == number
  if type(choice) == "string" and number ~= 0 then
    won = (choice == "red" and red[number])
      or (choice == "black" and not red[number])
      or (choice == "odd" and number % 2 == 1)
      or (choice == "even" and number % 2 == 0)
      or (choice == "low" and number <= 18)
      or (choice == "high" and number >= 19)
  end
  local multiplier = type(choice) == "number" and 36 or 2
  return {
    phase = "settled", bet = bet, choice = choice, number = number,
    colour = number == 0 and "green" or (red[number] and "red" or "black"),
    outcome = won and "win" or "lose", payout = won and bet * multiplier or 0,
  }
end

function roulette.view(game)
  local state = game.state
  return {
    gameId=game.id, game="roulette", revision=game.revision, phase=state.phase,
    bet=state.bet, choice=state.choice, number=state.number, colour=state.colour,
    outcome=state.outcome, payout=state.payout,
  }
end

return roulette
