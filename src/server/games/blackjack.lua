local blackjack = {}

local ranks = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
local suits = { "spades", "hearts", "diamonds", "clubs" }

local function shuffle(cards)
  for index = #cards, 2, -1 do
    local other = math.random(index)
    cards[index], cards[other] = cards[other], cards[index]
  end
end

local function newShoe(deckCount)
  local cards = {}
  for _ = 1, deckCount do
    for _, suit in ipairs(suits) do
      for _, rank in ipairs(ranks) do
        table.insert(cards, { rank = rank, suit = suit })
      end
    end
  end
  shuffle(cards)
  return cards
end

local function draw(state, hand)
  local card = table.remove(state.shoe)
  assert(card, "Blackjack shoe is empty")
  table.insert(hand, card)
end

function blackjack.score(cards)
  local total = 0
  local aces = 0
  for _, card in ipairs(cards) do
    if card.rank == "A" then
      aces = aces + 1
      total = total + 11
    elseif card.rank == "K" or card.rank == "Q" or card.rank == "J" then
      total = total + 10
    else
      total = total + tonumber(card.rank)
    end
  end
  while total > 21 and aces > 0 do
    total = total - 10
    aces = aces - 1
  end
  return total, aces > 0
end

local function isNatural(cards)
  return #cards == 2 and blackjack.score(cards) == 21
end

local function dealerTurn(state, dealerHitsSoft17)
  while true do
    local total, soft = blackjack.score(state.dealerCards)
    if total > 17 or (total == 17 and (not soft or not dealerHitsSoft17)) then
      break
    end
    draw(state, state.dealerCards)
  end
end

local function settle(state, dealerHitsSoft17)
  dealerTurn(state, dealerHitsSoft17)
  local playerTotal = blackjack.score(state.playerCards)
  local dealerTotal = blackjack.score(state.dealerCards)

  if playerTotal > 21 then
    state.outcome = "lose"
    state.payout = 0
  elseif dealerTotal > 21 or playerTotal > dealerTotal then
    state.outcome = "win"
    state.payout = state.bet * 2
  elseif playerTotal == dealerTotal then
    state.outcome = "push"
    state.payout = state.bet
  else
    state.outcome = "lose"
    state.payout = 0
  end
  state.phase = "settled"
end

function blackjack.create(bet, rules)
  local state = {
    phase = "player_turn",
    bet = bet,
    originalBet = bet,
    shoe = newShoe(rules.decks or 6),
    playerCards = {},
    dealerCards = {},
    outcome = nil,
    payout = 0,
  }

  draw(state, state.playerCards)
  draw(state, state.dealerCards)
  draw(state, state.playerCards)
  draw(state, state.dealerCards)

  local playerNatural = isNatural(state.playerCards)
  local dealerNatural = isNatural(state.dealerCards)
  if playerNatural or dealerNatural then
    state.phase = "settled"
    if playerNatural and dealerNatural then
      state.outcome = "push"
      state.payout = bet
    elseif playerNatural then
      state.outcome = "blackjack"
      state.payout = bet + math.floor(
        bet * rules.blackjackPayoutNumerator / rules.blackjackPayoutDenominator
      )
    else
      state.outcome = "lose"
      state.payout = 0
    end
  end

  return state
end

function blackjack.canDouble(state)
  return state.phase == "player_turn"
    and #state.playerCards == 2
    and state.bet == state.originalBet
end

function blackjack.action(state, action, rules)
  if state.phase ~= "player_turn" then
    return nil, "GAME_FINISHED"
  end

  if action == "hit" then
    draw(state, state.playerCards)
    local total = blackjack.score(state.playerCards)
    if total > 21 then
      state.phase = "settled"
      state.outcome = "lose"
      state.payout = 0
    elseif total == 21 then
      settle(state, rules.dealerHitsSoft17)
    end
  elseif action == "stand" then
    settle(state, rules.dealerHitsSoft17)
  elseif action == "double" and blackjack.canDouble(state) then
    state.bet = state.bet * 2
    draw(state, state.playerCards)
    if blackjack.score(state.playerCards) > 21 then
      state.phase = "settled"
      state.outcome = "lose"
      state.payout = 0
    else
      settle(state, rules.dealerHitsSoft17)
    end
  else
    return nil, "INVALID_ACTION"
  end
  return state
end

local function publicCards(cards, hideSecond)
  local result = {}
  for index, card in ipairs(cards) do
    if hideSecond and index == 2 then
      result[index] = { hidden = true }
    else
      result[index] = { rank = card.rank, suit = card.suit }
    end
  end
  return result
end

function blackjack.view(game)
  local state = game.state
  local playerTotal = blackjack.score(state.playerCards)
  local dealerHidden = state.phase ~= "settled"
  local actions = {}
  if state.phase == "player_turn" then
    actions = { "hit", "stand" }
    if blackjack.canDouble(state) then table.insert(actions, "double") end
  end

  return {
    gameId = game.id,
    game = "blackjack",
    revision = game.revision,
    phase = state.phase,
    bet = state.bet,
    playerCards = publicCards(state.playerCards, false),
    dealerCards = publicCards(state.dealerCards, dealerHidden),
    playerTotal = playerTotal,
    dealerTotal = dealerHidden and nil or blackjack.score(state.dealerCards),
    actions = actions,
    outcome = state.outcome,
    payout = state.payout,
  }
end

return blackjack
