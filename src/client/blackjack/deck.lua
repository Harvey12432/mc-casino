local deck = {}

function deck.cardLabel(card)
  if card.hidden then
    return "??"
  end
  return ("%s%s"):format(card.rank, card.suit:sub(1, 1):upper())
end

function deck.handLabel(cards)
  local labels = {}
  for index, card in ipairs(cards) do
    labels[index] = deck.cardLabel(card)
  end
  return table.concat(labels, " ")
end

return deck
