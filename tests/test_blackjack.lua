local blackjack = require("server.games.blackjack")

local tests = {}

local function cards(...)
  local result = {}
  for _, rank in ipairs({ ... }) do
    table.insert(result, { rank = rank, suit = "spades" })
  end
  return result
end

function tests.aces_are_reduced_to_avoid_bust()
  assert(blackjack.score(cards("A", "A", "9")) == 21)
end

function tests.face_cards_are_worth_ten()
  assert(blackjack.score(cards("K", "Q")) == 20)
end

function tests.player_can_double_only_on_first_two_cards()
  local state = {
    phase = "player_turn",
    bet = 10,
    originalBet = 10,
    playerCards = cards("5", "6"),
  }
  assert(blackjack.canDouble(state))
  table.insert(state.playerCards, { rank = "2", suit = "hearts" })
  assert(not blackjack.canDouble(state))
end

return tests
