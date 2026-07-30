local protocol = require("shared.protocol")

local handler = {}
handler.__index = handler

function handler.new(gameService)
  return setmetatable({ gameService = gameService }, handler)
end

function handler:handle(senderId, message, session)
  if message.type == protocol.types.GAME_CREATE then
    return self.gameService:create(
      message.requestId,
      session.playerId,
      message.payload.game,
      message.payload.bet,
      senderId,
      message.payload.options,
      session.role == "admin" and message.payload.acceptanceTest == true
    )
  end

  if message.type == protocol.types.GAME_ACTION then
    return self.gameService:action(
      message.requestId,
      session.playerId,
      message.payload.gameId,
      message.payload.action,
      message.payload.expectedRevision,
      message.payload
    )
  end

  if message.type == protocol.types.GAME_VIEW then
    return self.gameService:get(session.playerId, message.payload.gameId)
  end

  return nil, "BAD_REQUEST"
end

return handler
