local TransactionService = require("server.services.transaction_service")
local AccountService = require("server.services.account_service")

local tests = {}

local function services()
  local players = {}
  local transactions = {}

  local playerRepository = {}
  function playerRepository:get(id) return players[id] end
  function playerRepository:save(player)
    players[player.id] = player
    return player
  end
  function playerRepository:all() return players end

  local transactionRepository = {}
  function transactionRepository:all() return transactions end
  function transactionRepository:findByRequestId(requestId)
    for _, transaction in ipairs(transactions) do
      if transaction.requestId == requestId then return transaction end
    end
  end
  function transactionRepository:append(transaction)
    table.insert(transactions, transaction)
    return transaction
  end

  local transactionService = TransactionService.new(transactionRepository)
  return AccountService.new(playerRepository, transactionService, 100, 1000), transactions
end

function tests.new_players_receive_starting_balance()
  local accounts = services()
  local player = accounts:getOrCreate("Harvey")
  assert(player.id == "harvey")
  assert(player.balance == 100)
end

function tests.debits_cannot_overdraw()
  local accounts = services()
  accounts:getOrCreate("Harvey")
  local transaction, changeError = accounts:change(
    "too-much",
    "harvey",
    -101,
    "test",
    "test"
  )
  assert(transaction == nil)
  assert(changeError == "INSUFFICIENT_FUNDS")
  assert(accounts:get("harvey").balance == 100)
end

function tests.duplicate_request_is_applied_once()
  local accounts, transactions = services()
  accounts:getOrCreate("Harvey")
  accounts:change("same-request", "harvey", -10, "test", "test")
  accounts:change("same-request", "harvey", -10, "test", "test")
  assert(accounts:get("harvey").balance == 90)
  assert(#transactions == 1)
end

function tests.duplicate_request_cannot_change_its_meaning()
  local service = services()
  service:getOrCreate("Alice")
  assert(service:change("same-id", "alice", 10, "deposit", "cashier:1"))
  local transaction, changeError = service:change(
    "same-id",
    "alice",
    20,
    "deposit",
    "cashier:1"
  )
  assert(transaction == nil)
  assert(changeError == "REQUEST_CONFLICT")
  assert(service:get("alice").balance == 110)
end

function tests.missing_audit_entry_is_repaired_without_reapplying_balance()
  local accounts, transactions = services()
  accounts:getOrCreate("Harvey")
  accounts:change("repair-me", "harvey", -10, "test", "test")
  table.remove(transactions, 1)
  accounts:repairTransactions()
  assert(accounts:get("harvey").balance == 90)
  assert(#transactions == 1)
  assert(transactions[1].requestId == "repair-me")
end

function tests.non_finite_and_excessive_balances_are_rejected()
  local accounts = services()
  accounts:getOrCreate("Harvey")
  local infinite, infiniteError = accounts:change(
    "infinite",
    "harvey",
    math.huge,
    "test",
    "test"
  )
  assert(infinite == nil)
  assert(infiniteError == "BAD_REQUEST")

  local excessive, excessiveError = accounts:change(
    "excessive",
    "harvey",
    901,
    "test",
    "test"
  )
  assert(excessive == nil)
  assert(excessiveError == "BALANCE_LIMIT")
  assert(accounts:get("harvey").balance == 100)
end

return tests
