local mines = {}

local function combinations(n, k)
  local value = 1
  for index = 1, k do
    value = value * (n - k + index) / index
  end
  return value
end

local function multiplier(mineCount, revealed)
  if revealed == 0 then return 1 end
  local safe = 25 - mineCount
  return 0.95 * combinations(25, revealed) / combinations(safe, revealed)
end

function mines.validate(options)
  local count = options and tonumber(options.mines) or 3
  return count == math.floor(count) and count >= 1 and count <= 20
end

function mines.create(bet, options)
  local count = tonumber(options and options.mines) or 3
  local positions = {}
  for index = 1, 25 do positions[index] = index end
  for index = #positions, 2, -1 do
    local other = math.random(index)
    positions[index], positions[other] = positions[other], positions[index]
  end
  local mineMap = {}
  for index = 1, count do mineMap[tostring(positions[index])] = true end
  return {
    phase="playing", bet=bet, mineCount=count, mines=mineMap, revealed={},
    revealedCount=0, multiplier=1, payout=0, outcome=nil,
  }
end

function mines.action(state, action, payload)
  if state.phase ~= "playing" then return nil, "GAME_FINISHED" end
  if action == "reveal" then
    local position = payload and tonumber(payload.position)
    if not position or position ~= math.floor(position)
      or position < 1 or position > 25 or state.revealed[tostring(position)]
    then
      return nil, "INVALID_ACTION"
    end
    if state.mines[tostring(position)] then
      state.phase, state.outcome, state.payout = "settled", "lose", 0
      state.hit = position
    else
      state.revealed[tostring(position)] = true
      state.revealedCount = state.revealedCount + 1
      state.multiplier = multiplier(state.mineCount, state.revealedCount)
      if state.revealedCount == 25 - state.mineCount then
        state.phase, state.outcome = "settled", "win"
        state.payout = math.floor(state.bet * state.multiplier)
      end
    end
  elseif action == "cashout" and state.revealedCount > 0 then
    state.phase, state.outcome = "settled", "cashout"
    state.payout = math.floor(state.bet * state.multiplier)
  else
    return nil, "INVALID_ACTION"
  end
  return state
end

function mines.view(game)
  local s, revealed = game.state, {}
  for position in pairs(game.state.revealed) do
    table.insert(revealed, tonumber(position))
  end
  table.sort(revealed)
  local result = {
    gameId=game.id, game="mines", revision=game.revision, phase=s.phase,
    bet=s.bet, mineCount=s.mineCount, revealed=revealed,
    revealedCount=s.revealedCount, multiplier=s.multiplier,
    actions=s.phase == "playing" and {"reveal", "cashout"} or {},
    outcome=s.outcome, payout=s.payout,
  }
  if s.phase == "settled" then
    result.mines = {}
    for position in pairs(s.mines) do
      table.insert(result.mines, tonumber(position))
    end
    table.sort(result.mines)
    result.hit = s.hit
  end
  return result
end

return mines
