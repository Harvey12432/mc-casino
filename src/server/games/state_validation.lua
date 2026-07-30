local validation = {}

local ranks = {
  A=true, ["2"]=true, ["3"]=true, ["4"]=true, ["5"]=true, ["6"]=true,
  ["7"]=true, ["8"]=true, ["9"]=true, ["10"]=true, J=true, Q=true, K=true,
}
local blackjackSuits = {
  spades=true, hearts=true, diamonds=true, clubs=true,
}
local pokerSuits = { S=true, H=true, D=true, C=true }
local slotSymbols = {
  cherry=true, lemon=true, bell=true, diamond=true, seven=true,
}
local slotMultipliers = {
  cherry=2, lemon=3, bell=5, diamond=8, seven=15,
}
local legacySlotMultipliers = {
  cherry=3, lemon=4, bell=6, diamond=10, seven=20,
}

local function finite(value)
  return type(value) == "number"
    and value == value
    and value < math.huge
    and value > -math.huge
end

local function integer(value, minimum, maximum)
  return finite(value)
    and value == math.floor(value)
    and value >= (minimum or -math.huge)
    and value <= (maximum or math.huge)
end

local function member(value, values)
  return values[value] == true
end

local function validArray(value, minimum, maximum, itemValidator)
  if type(value) ~= "table" then return false end
  local count = 0
  for key, item in pairs(value) do
    if not integer(key, 1) or not itemValidator(item, key) then return false end
    count = count + 1
  end
  return count == #value
    and count >= (minimum or 0)
    and count <= (maximum or math.huge)
end

local function blackjackCard(card)
  return type(card) == "table"
    and member(card.rank, ranks)
    and member(card.suit, blackjackSuits)
end

local function pokerCard(card)
  return type(card) == "table"
    and member(card.rank, ranks)
    and member(card.suit, pokerSuits)
end

local function validOutcome(state, activePhase, outcomes)
  if state.phase == activePhase then return state.outcome == nil end
  return member(state.outcome, outcomes)
end

local function validSlots(state)
  if state.phase ~= "settled"
    or not validArray(state.reels, 3, 3, function(symbol)
      return member(symbol, slotSymbols)
    end)
  then
    return false
  end
  if state.rulesVersion ~= nil and state.rulesVersion ~= 2 then return false end
  local multipliers = state.rulesVersion == 2
    and slotMultipliers
    or legacySlotMultipliers
  local pairMultiplier = state.rulesVersion == 2 and 1 or 2
  local basePayout = 0
  if state.reels[1] == state.reels[2] and state.reels[2] == state.reels[3] then
    basePayout = state.bet * multipliers[state.reels[1]]
  elseif state.reels[1] == state.reels[2]
    or state.reels[1] == state.reels[3]
    or state.reels[2] == state.reels[3]
  then
    basePayout = state.bet * pairMultiplier
  end
  local expectedJackpot = state.reels[1] == "seven"
    and state.reels[2] == "seven"
    and state.reels[3] == "seven"
  local expectedOutcome = basePayout == 0 and "lose"
    or (state.rulesVersion == 2 and basePayout == state.bet
      and "push"
      or "win")
  return member(state.outcome, { win=true, lose=true, push=true })
    and state.outcome == expectedOutcome
    and type(state.jackpot) == "boolean"
    and state.jackpot == expectedJackpot
    and (state.jackpotAmount == nil or integer(state.jackpotAmount, 0))
    and state.payout == basePayout + (state.jackpotAmount or 0)
end

local function validBlackjack(state)
  if state.phase ~= "player_turn" and state.phase ~= "settled" then return false end
  return integer(state.originalBet, 1)
    and integer(state.bet, state.originalBet)
    and validArray(state.shoe, 0, 416, blackjackCard)
    and validArray(state.playerCards, 2, 22, blackjackCard)
    and validArray(state.dealerCards, 2, 22, blackjackCard)
    and validOutcome(
      state,
      "player_turn",
      { win=true, lose=true, push=true, blackjack=true }
    )
    and (state.phase == "player_turn"
      and state.payout == 0
      or state.outcome == "lose" and state.payout == 0
      or state.outcome == "push" and state.payout == state.bet
      or state.outcome == "win" and state.payout == state.bet * 2
      or state.outcome == "blackjack"
        and state.bet == state.originalBet
        and state.payout == state.bet + math.floor(state.bet * 3 / 2))
end

local rouletteChoices = {
  red=true, black=true, odd=true, even=true, low=true, high=true,
}
local redNumbers = {
  [1]=true,[3]=true,[5]=true,[7]=true,[9]=true,[12]=true,[14]=true,
  [16]=true,[18]=true,[19]=true,[21]=true,[23]=true,[25]=true,
  [27]=true,[30]=true,[32]=true,[34]=true,[36]=true,
}
local function rouletteChoice(choice)
  return integer(choice, 0, 36) or member(choice, rouletteChoices)
end

local function rouletteResult(record)
  local won = record.choice == record.number
  if type(record.choice) == "string" and record.number ~= 0 then
    won = record.choice == "red" and redNumbers[record.number] == true
      or record.choice == "black" and not redNumbers[record.number]
      or record.choice == "odd" and record.number % 2 == 1
      or record.choice == "even" and record.number % 2 == 0
      or record.choice == "low" and record.number <= 18
      or record.choice == "high" and record.number >= 19
  end
  local colour = record.number == 0 and "green"
    or (redNumbers[record.number] and "red" or "black")
  local payout = won
    and record.bet * (type(record.choice) == "number" and 36 or 2)
    or 0
  return won, colour, payout
end

local function validRoulette(state)
  if state.phase ~= "settled"
    or not rouletteChoice(state.choice)
    or not integer(state.number, 0, 36)
    or not member(state.colour, { red=true, black=true, green=true })
  then
    return false
  end
  local won, expectedColour, expectedPayout = rouletteResult(state)
  return state.colour == expectedColour
    and state.outcome == (won and "win" or "lose")
    and state.payout == expectedPayout
end

local function validCrash(state)
  if state.phase ~= "running" and state.phase ~= "settled" then return false end
  if not finite(state.startedAt)
    or state.startedAt < 0
    or not integer(state.crashPoint, 100, 100000)
    or not integer(state.multiplier, 100, state.crashPoint)
  then
    return false
  end
  if state.phase == "running" then
    return state.outcome == nil and state.payout == 0
  end
  if state.outcome == "crashed" then
    return state.payout == 0 and state.multiplier == state.crashPoint
  end
  return state.outcome == "cashout"
    and state.payout == math.floor(state.bet * state.multiplier / 100)
end

local function positionMap(value)
  if type(value) ~= "table" then return false, 0 end
  local count = 0
  for position, present in pairs(value) do
    local number = tonumber(position)
    if present ~= true
      or tostring(number) ~= position
      or not integer(number, 1, 25)
    then
      return false, 0
    end
    count = count + 1
  end
  return true, count
end

local function validMines(state)
  if state.phase ~= "playing" and state.phase ~= "settled" then return false end
  local minesValid, mineCount = positionMap(state.mines)
  local revealedValid, revealedCount = positionMap(state.revealed)
  if not minesValid
    or not revealedValid
    or not integer(state.mineCount, 1, 20)
    or mineCount ~= state.mineCount
    or not integer(state.revealedCount, 0, 24)
    or revealedCount ~= state.revealedCount
    or not finite(state.multiplier)
    or state.multiplier <= 0
  then
    return false
  end
  for position in pairs(state.revealed) do
    if state.mines[position] then return false end
  end
  if state.phase == "playing" then
    return state.outcome == nil and state.hit == nil and state.payout == 0
  end
  if not member(state.outcome, { win=true, lose=true, cashout=true }) then
    return false
  end
  local validHit = state.hit == nil
    or (integer(state.hit, 1, 25) and state.mines[tostring(state.hit)] == true)
  local expectedPayout = state.outcome == "lose"
    and 0
    or math.floor(state.bet * state.multiplier)
  return validHit
    and state.payout == expectedPayout
    and (state.outcome == "lose") == (state.hit ~= nil)
end

local plinkoMultipliers = {
  [10]=true, [3]=true, [1.5]=true, [0.7]=true, [0.3]=true,
}
local function validPlinko(state)
  if state.phase ~= "settled"
    or not validArray(state.path, 8, 8, function(direction)
      return direction == "L" or direction == "R"
    end)
    or not integer(state.bin, 1, 9)
    or not plinkoMultipliers[state.multiplier]
    or not member(state.outcome, { win=true, lose=true, push=true })
  then
    return false
  end
  local expectedBin = 1
  for _, direction in ipairs(state.path) do
    if direction == "R" then expectedBin = expectedBin + 1 end
  end
  return state.bin == expectedBin
    and state.payout == math.floor(state.bet * state.multiplier)
    and state.outcome == (state.multiplier > 1 and "win"
      or (state.multiplier == 1 and "push" or "lose"))
end

local function validHorseRacing(state)
  if state.phase ~= "settled"
    or (state.rulesVersion ~= nil and state.rulesVersion ~= 2)
    or not integer(state.selected, 1, 5)
    or not integer(state.winner, 1, 5)
    or not member(state.outcome, { win=true, lose=true })
    or not validArray(state.order, 5, 5, function(horse)
      return integer(horse, 1, 5)
    end)
  then
    return false
  end
  local seen = {}
  for _, horse in ipairs(state.order) do
    if seen[horse] then return false end
    seen[horse] = true
  end
  local won = state.selected == state.winner
  local payoutMultiplier = state.rulesVersion == 2 and 5 or 4
  return state.winner == state.order[1]
    and state.outcome == (won and "win" or "lose")
    and state.payout == (won and state.bet * payoutMultiplier or 0)
end

local pokerOutcomes = {
  royal_flush=true, straight_flush=true, four_kind=true, full_house=true,
  flush=true, straight=true, three_kind=true, two_pair=true,
  jacks_or_better=true, nothing=true,
}
local function validPoker(state)
  if state.phase ~= "draw" and state.phase ~= "settled" then return false end
  if not validArray(state.deck, 0, 47, pokerCard)
    or not validArray(state.hand, 5, 5, pokerCard)
  then
    return false
  end
  local seen = {}
  for _, collection in ipairs({ state.deck, state.hand }) do
    for _, card in ipairs(collection) do
      local key = card.rank .. card.suit
      if seen[key] then return false end
      seen[key] = true
    end
  end
  if state.phase == "draw" then
    return state.outcome == nil
      and state.multiplier == nil
      and state.payout == 0
  end
  return member(state.outcome, pokerOutcomes)
    and integer(state.multiplier, 0, 250)
    and state.payout == state.bet * state.multiplier
end

local function dice(value)
  return validArray(value, 2, 2, function(die)
    return integer(die, 1, 6)
  end)
end

local function historyEntry(entry)
  return type(entry) == "table"
    and dice(entry.dice)
    and integer(entry.total, 2, 12)
    and entry.total == entry.dice[1] + entry.dice[2]
end

local function validCraps(state)
  if state.phase ~= "point" and state.phase ~= "settled" then return false end
  if not dice(state.dice)
    or not integer(state.total, 2, 12)
    or state.total ~= state.dice[1] + state.dice[2]
    or not validArray(state.history, 1, 20, historyEntry)
  then
    return false
  end
  local latest = state.history[#state.history]
  if latest.total ~= state.total
    or latest.dice[1] ~= state.dice[1]
    or latest.dice[2] ~= state.dice[2]
  then
    return false
  end
  local pointValid = state.point == nil
    or member(state.point, { [4]=true, [5]=true, [6]=true, [8]=true, [9]=true, [10]=true })
  if not pointValid then return false end
  if state.phase == "point" then
    return state.point ~= nil and state.outcome == nil and state.payout == 0
  end
  return member(state.outcome, { win=true, lose=true })
    and state.payout == (state.outcome == "win" and state.bet * 2 or 0)
end

local function validCoinFlip(state)
  local won = state.choice == state.result
  return state.phase == "settled"
    and member(state.choice, { heads=true, tails=true })
    and member(state.result, { heads=true, tails=true })
    and state.outcome == (won and "win" or "lose")
    and state.payout == (won and state.bet * 2 or 0)
end

local validators = {
  slots = validSlots,
  blackjack = validBlackjack,
  roulette = validRoulette,
  crash = validCrash,
  mines = validMines,
  plinko = validPlinko,
  horse_racing = validHorseRacing,
  poker = validPoker,
  craps = validCraps,
  coin_flip = validCoinFlip,
}

function validation.valid(gameType, state)
  if type(state) ~= "table"
    or not integer(state.bet, 1)
    or not integer(state.payout, 0)
  then
    return false
  end
  local validator = validators[gameType]
  if validator == nil or validator(state) ~= true then return false end
  if state.creditedPayout == nil then
    return state.payoutCapped == nil
  end
  return integer(state.creditedPayout, 0, state.payout)
    and state.creditedPayout < state.payout
    and state.payoutCapped == true
end

local function publicBlackjackCard(card)
  return type(card) == "table"
    and ((card.hidden == true and card.rank == nil and card.suit == nil)
      or blackjackCard(card))
end

local function validActions(actions, allowed)
  return validArray(actions, 0, 3, function(action)
    return member(action, allowed)
  end)
end

local function numberList(values, minimum, maximum)
  local seen = {}
  return validArray(values, 0, maximum - minimum + 1, function(value)
    if not integer(value, minimum, maximum) or seen[value] then return false end
    seen[value] = true
    return true
  end)
end

local function validViewSpecific(gameType, view)
  if gameType == "slots" then
    return view.phase == "settled"
      and (view.rulesVersion == nil or view.rulesVersion == 2)
      and validArray(view.reels, 3, 3, function(symbol)
        return member(symbol, slotSymbols)
      end)
      and member(view.outcome, { win=true, lose=true, push=true })
      and integer(view.jackpot, 0)
  elseif gameType == "blackjack" then
    if view.phase ~= "player_turn" and view.phase ~= "settled" then return false end
    return validArray(view.playerCards, 2, 22, blackjackCard)
      and validArray(view.dealerCards, 2, 22, publicBlackjackCard)
      and integer(view.playerTotal, 4, 31)
      and (view.dealerTotal == nil or integer(view.dealerTotal, 4, 31))
      and validActions(view.actions, { hit=true, stand=true, double=true })
      and validOutcome(
        view,
        "player_turn",
        { win=true, lose=true, push=true, blackjack=true }
      )
  elseif gameType == "roulette" then
    return view.phase == "settled"
      and rouletteChoice(view.choice)
      and integer(view.number, 0, 36)
      and member(view.colour, { red=true, black=true, green=true })
      and member(view.outcome, { win=true, lose=true })
  elseif gameType == "crash" then
    if view.phase ~= "running" and view.phase ~= "settled" then return false end
    return integer(view.multiplier, 100, 100000)
      and validActions(view.actions, { cashout=true })
      and (view.phase == "running"
        and view.outcome == nil
        and view.crashPoint == nil
        or view.phase == "settled"
          and member(view.outcome, { cashout=true, crashed=true })
          and integer(view.crashPoint, 100, 100000))
  elseif gameType == "mines" then
    if view.phase ~= "playing" and view.phase ~= "settled" then return false end
    return integer(view.mineCount, 1, 20)
      and numberList(view.revealed, 1, 25)
      and #view.revealed == view.revealedCount
      and finite(view.multiplier)
      and view.multiplier > 0
      and validActions(view.actions, { reveal=true, cashout=true })
      and (view.phase == "playing"
        and view.mines == nil
        and view.outcome == nil
        or view.phase == "settled"
          and numberList(view.mines, 1, 25)
          and #view.mines == view.mineCount
          and member(view.outcome, { win=true, lose=true, cashout=true }))
  elseif gameType == "plinko" then
    return view.phase == "settled"
      and validArray(view.path, 8, 8, function(direction)
        return direction == "L" or direction == "R"
      end)
      and integer(view.bin, 1, 9)
      and plinkoMultipliers[view.multiplier] == true
      and member(view.outcome, { win=true, lose=true, push=true })
  elseif gameType == "horse_racing" then
    return view.phase == "settled"
      and (view.rulesVersion == nil or view.rulesVersion == 2)
      and integer(view.selected, 1, 5)
      and integer(view.winner, 1, 5)
      and numberList(view.order, 1, 5)
      and #view.order == 5
      and view.winner == view.order[1]
      and member(view.outcome, { win=true, lose=true })
  elseif gameType == "poker" then
    return (view.phase == "draw" or view.phase == "settled")
      and validArray(view.hand, 5, 5, pokerCard)
      and validActions(view.actions, { draw=true })
      and (view.phase == "draw"
        and view.outcome == nil
        or view.phase == "settled"
          and member(view.outcome, pokerOutcomes)
          and integer(view.multiplier, 0, 250))
  elseif gameType == "craps" then
    return (view.phase == "point" or view.phase == "settled")
      and dice(view.dice)
      and integer(view.total, 2, 12)
      and view.total == view.dice[1] + view.dice[2]
      and (view.point == nil
        or member(view.point, {
          [4]=true, [5]=true, [6]=true, [8]=true, [9]=true, [10]=true,
        }))
      and validArray(view.history, 1, 20, historyEntry)
      and validActions(view.actions, { roll=true })
      and (view.phase == "point" and view.outcome == nil
        or view.phase == "settled"
          and member(view.outcome, { win=true, lose=true }))
  elseif gameType == "coin_flip" then
    return view.phase == "settled"
      and member(view.choice, { heads=true, tails=true })
      and member(view.result, { heads=true, tails=true })
      and member(view.outcome, { win=true, lose=true })
  end
  return false
end

local function validViewPayout(gameType, view)
  local payout = view.grossPayout or view.payout
  if gameType == "slots" then
    local multipliers = view.rulesVersion == 2
      and slotMultipliers
      or legacySlotMultipliers
    local pairMultiplier = view.rulesVersion == 2 and 1 or 2
    local basePayout = 0
    if view.reels[1] == view.reels[2] and view.reels[2] == view.reels[3] then
      basePayout = view.bet * multipliers[view.reels[1]]
    elseif view.reels[1] == view.reels[2]
      or view.reels[1] == view.reels[3]
      or view.reels[2] == view.reels[3]
    then
      basePayout = view.bet * pairMultiplier
    end
    local expectedOutcome = basePayout == 0 and "lose"
      or (view.rulesVersion == 2 and basePayout == view.bet
        and "push"
        or "win")
    return view.outcome == expectedOutcome
      and payout == basePayout + view.jackpot
  elseif gameType == "blackjack" then
    return view.phase == "player_turn" and payout == 0
      or view.outcome == "lose" and payout == 0
      or view.outcome == "push" and payout == view.bet
      or view.outcome == "win" and payout == view.bet * 2
      or view.outcome == "blackjack"
        and payout == view.bet + math.floor(view.bet * 3 / 2)
  elseif gameType == "roulette" then
    local won, colour, expectedPayout = rouletteResult(view)
    return view.colour == colour
      and view.outcome == (won and "win" or "lose")
      and payout == expectedPayout
  elseif gameType == "crash" then
    return view.phase == "running" and payout == 0
      or view.outcome == "crashed" and payout == 0
      or view.outcome == "cashout"
        and payout == math.floor(view.bet * view.multiplier / 100)
  elseif gameType == "mines" then
    return view.phase == "playing" and payout == 0
      or view.outcome == "lose" and payout == 0
      or (view.outcome == "win" or view.outcome == "cashout")
        and payout == math.floor(view.bet * view.multiplier)
  elseif gameType == "plinko" then
    return payout == math.floor(view.bet * view.multiplier)
      and view.outcome == (view.multiplier > 1 and "win"
        or (view.multiplier == 1 and "push" or "lose"))
  elseif gameType == "horse_racing" then
    local won = view.selected == view.winner
    local payoutMultiplier = view.rulesVersion == 2 and 5 or 4
    return view.outcome == (won and "win" or "lose")
      and payout == (won and view.bet * payoutMultiplier or 0)
  elseif gameType == "poker" then
    return view.phase == "draw" and payout == 0
      or view.phase == "settled"
        and payout == view.bet * view.multiplier
  elseif gameType == "craps" then
    return view.phase == "point" and payout == 0
      or view.phase == "settled"
        and payout == (view.outcome == "win" and view.bet * 2 or 0)
  elseif gameType == "coin_flip" then
    local won = view.choice == view.result
    return view.outcome == (won and "win" or "lose")
      and payout == (won and view.bet * 2 or 0)
  end
  return false
end

function validation.validView(gameType, view)
  if type(view) ~= "table" then return false end
  if view.game ~= gameType
    or type(view.gameId) ~= "string"
    or not integer(view.revision, 1)
    or not integer(view.bet, 1)
    or not integer(view.payout, 0)
  then
    return false
  end
  local capValid = (view.grossPayout == nil
      and view.payoutCapped == nil)
    or (integer(view.grossPayout, view.payout)
      and view.grossPayout > view.payout
      and view.payoutCapped == true)
  return capValid
    and validViewSpecific(gameType, view)
    and validViewPayout(gameType, view)
end

return validation
