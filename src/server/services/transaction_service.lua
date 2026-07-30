local transactionService = {}
transactionService.__index = transactionService

function transactionService.new(transactionRepository)
  return setmetatable({
    transactionRepository = transactionRepository,
  }, transactionService)
end

function transactionService:find(requestId)
  return self.transactionRepository:findByRequestId(requestId)
end

function transactionService:record(transaction)
  return self.transactionRepository:append(transaction)
end

function transactionService:list(limit)
  local all = self.transactionRepository:all()
  local result = {}
  local first = math.max(1, #all - (limit or 50) + 1)
  for index = #all, first, -1 do
    table.insert(result, all[index])
  end
  return result
end

function transactionService:houseProfit()
  local profit = 0
  for _, transaction in ipairs(self.transactionRepository:all()) do
    if transaction.kind == "game_bet"
      or transaction.kind == "game_payout"
      or transaction.kind == "game_double"
    then
      profit = profit - transaction.amount
    end
  end
  return profit
end

return transactionService
