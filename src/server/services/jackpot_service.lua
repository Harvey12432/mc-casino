local jackpotService = {}
jackpotService.__index = jackpotService

function jackpotService.new(jackpotRepository)
  return setmetatable({ jackpotRepository = jackpotRepository }, jackpotService)
end

function jackpotService:get(name)
  return self.jackpotRepository:get(name)
end

function jackpotService:process(requestId, name, contribution, claim)
  return self.jackpotRepository:process(
    requestId,
    name,
    contribution,
    claim
  )
end

return jackpotService
