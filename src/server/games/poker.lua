local poker = {}
local ranks = { "2","3","4","5","6","7","8","9","10","J","Q","K","A" }
local suits = { "S", "H", "D", "C" }
local values = {}
for index, rank in ipairs(ranks) do values[rank] = index + 1 end

local function shuffledDeck()
  local deck = {}
  for _, suit in ipairs(suits) do
    for _, rank in ipairs(ranks) do table.insert(deck, {rank=rank, suit=suit}) end
  end
  for index = #deck, 2, -1 do
    local other = math.random(index)
    deck[index], deck[other] = deck[other], deck[index]
  end
  return deck
end

local function draw(deck) return table.remove(deck) end

function poker.evaluate(hand)
  local counts, ordered, flush = {}, {}, true
  for index, card in ipairs(hand) do
    local value = values[card.rank]
    counts[value] = (counts[value] or 0) + 1
    ordered[index] = value
    if index > 1 and card.suit ~= hand[1].suit then flush = false end
  end
  table.sort(ordered)
  local straight = true
  for index = 2, 5 do
    if ordered[index] ~= ordered[1] + index - 1 then straight = false end
  end
  if table.concat(ordered, ",") == "2,3,4,5,14" then straight = true end
  local groups, highPair = {}, false
  for value, count in pairs(counts) do
    table.insert(groups, count)
    if count == 2 and value >= 11 then highPair = true end
  end
  table.sort(groups, function(a,b) return a > b end)
  if straight and flush and ordered[1] == 10 then return "royal_flush", 250 end
  if straight and flush then return "straight_flush", 50 end
  if groups[1] == 4 then return "four_kind", 25 end
  if groups[1] == 3 and groups[2] == 2 then return "full_house", 9 end
  if flush then return "flush", 6 end
  if straight then return "straight", 4 end
  if groups[1] == 3 then return "three_kind", 3 end
  if groups[1] == 2 and groups[2] == 2 then return "two_pair", 2 end
  if highPair then return "jacks_or_better", 1 end
  return "nothing", 0
end

function poker.validate() return true end
function poker.create(bet)
  local state = {phase="draw", bet=bet, deck=shuffledDeck(), hand={}, payout=0}
  for index = 1, 5 do state.hand[index] = draw(state.deck) end
  return state
end

function poker.action(state, action, payload)
  if state.phase ~= "draw" then return nil, "GAME_FINISHED" end
  if action ~= "draw" then return nil, "INVALID_ACTION" end
  local held = {}
  for _, index in ipairs((payload and payload.held) or {}) do
    index = tonumber(index)
    if not index or index ~= math.floor(index) or index < 1 or index > 5 then
      return nil, "INVALID_ACTION"
    end
    held[index] = true
  end
  for index = 1, 5 do if not held[index] then state.hand[index] = draw(state.deck) end end
  state.outcome, state.multiplier = poker.evaluate(state.hand)
  state.payout = state.bet * state.multiplier
  state.phase = "settled"
  return state
end

function poker.view(game)
  local s = game.state
  return {
    gameId=game.id, game="poker", revision=game.revision, phase=s.phase,
    bet=s.bet, hand=s.hand, actions=s.phase == "draw" and {"draw"} or {},
    outcome=s.outcome, multiplier=s.multiplier, payout=s.payout,
  }
end

return poker
