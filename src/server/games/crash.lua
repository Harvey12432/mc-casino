local crash = {}

local function currentMultiplier(state, now)
  local elapsed = math.max(0, now - state.startedAt)
  return math.min(100000, 100 + math.floor(elapsed / 100))
end

function crash.validate() return true end

function crash.create(bet)
  -- Roughly 1% instant bust chance, with a 1000x safety cap.
  local roll = math.random(1, 1000000) / 1000000
  local point = math.min(100000, math.max(100, math.floor(99 / (1 - roll))))
  return {
    phase="running", bet=bet, startedAt=os.epoch("utc"), crashPoint=point,
    multiplier=100, payout=0, outcome=nil,
  }
end

function crash.tick(state, now)
  if state.phase ~= "running" then return false end
  state.multiplier = currentMultiplier(state, now or os.epoch("utc"))
  if state.multiplier >= state.crashPoint then
    state.multiplier = state.crashPoint
    state.phase, state.outcome, state.payout = "settled", "crashed", 0
  end
  return true
end

function crash.action(state, action)
  if state.phase ~= "running" then return nil, "GAME_FINISHED" end
  crash.tick(state)
  if state.phase == "settled" then return state end
  if action ~= "cashout" then return nil, "INVALID_ACTION" end
  state.phase, state.outcome = "settled", "cashout"
  state.payout = math.floor(state.bet * state.multiplier / 100)
  return state
end

function crash.view(game)
  local s = game.state
  local result = {
    gameId=game.id, game="crash", revision=game.revision, phase=s.phase,
    bet=s.bet, multiplier=s.multiplier,
    actions=s.phase == "running" and {"cashout"} or {},
    outcome=s.outcome, payout=s.payout,
  }
  if s.phase == "settled" then result.crashPoint = s.crashPoint end
  return result
end

return crash
