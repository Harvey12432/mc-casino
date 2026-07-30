local game = {}

function game.new()
  return {
    gameId = nil,
    phase = "idle",
    revision = 0,
    playerCards = {},
    dealerCards = {},
    actions = {},
  }
end

-- The terminal stores only the authorised public view returned by the server.
function game.applyServerView(current, view)
  current.gameId = view.gameId or current.gameId
  current.phase = view.phase
  current.revision = view.revision
  current.playerCards = view.playerCards or {}
  current.dealerCards = view.dealerCards or {}
  current.actions = view.actions or {}
end

return game
