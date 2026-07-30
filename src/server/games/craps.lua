local craps = {}

local function roll()
  local dice = { math.random(1, 6), math.random(1, 6) }
  return dice, dice[1] + dice[2]
end

local function applyRoll(state)
  local dice, total = roll()
  state.dice, state.total = dice, total
  table.insert(state.history, { dice=dice, total=total })
  if #state.history > 20 then table.remove(state.history, 1) end
  if not state.point then
    if total == 7 or total == 11 then
      state.phase, state.outcome, state.payout = "settled", "win", state.bet * 2
    elseif total == 2 or total == 3 or total == 12 then
      state.phase, state.outcome, state.payout = "settled", "lose", 0
    else
      state.point = total
    end
  elseif total == state.point then
    state.phase, state.outcome, state.payout = "settled", "win", state.bet * 2
  elseif total == 7 then
    state.phase, state.outcome, state.payout = "settled", "lose", 0
  end
end

function craps.validate() return true end
function craps.create(bet)
  local state = {
    phase="come_out", bet=bet, point=nil, history={}, payout=0, outcome=nil,
  }
  applyRoll(state)
  if state.phase ~= "settled" then state.phase = "point" end
  return state
end

function craps.action(state, action)
  if state.phase == "settled" then return nil, "GAME_FINISHED" end
  if action ~= "roll" then return nil, "INVALID_ACTION" end
  applyRoll(state)
  return state
end

function craps.view(game)
  local s = game.state
  return {
    gameId=game.id, game="craps", revision=game.revision, phase=s.phase,
    bet=s.bet, dice=s.dice, total=s.total, point=s.point, history=s.history,
    actions=s.phase == "settled" and {} or {"roll"},
    outcome=s.outcome, payout=s.payout,
  }
end

return craps
