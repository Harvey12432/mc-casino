local SessionService = require("server.services.session_service")

local tests = {}

local function fixture()
  local accounts = {}
  function accounts:getOrCreate(name)
    return {
      id = name:lower(),
      displayName = name,
      balance = 0,
    }
  end
  return SessionService.new({
    authorizedAdminIds = { 10 },
    authorizedCashierIds = { 20 },
    sessionTimeout = 60,
  }, accounts)
end

function tests.sessions_are_bound_to_the_sender_computer()
  local sessions = fixture()
  local current = sessions:open(1, "Player")
  assert(sessions:authenticate(1, current.token))
  local denied, authError = sessions:authenticate(2, current.token)
  assert(denied == nil)
  assert(authError == "UNAUTHORIZED")
end

function tests.trusted_computer_ids_receive_roles()
  local sessions = fixture()
  local admin = sessions:open(10, "Owner")
  local cashier = sessions:open(20, "Cashier")
  assert(admin.role == "admin")
  assert(cashier.role == "cashier")
end

function tests.player_names_reject_whitespace_and_symbols()
  local sessions = fixture()
  local whitespace, whitespaceError = sessions:open(1, "Alice Smith")
  assert(whitespace == nil)
  assert(whitespaceError == "INVALID_PLAYER")
  local symbols, symbolsError = sessions:open(1, "../owner")
  assert(symbols == nil)
  assert(symbolsError == "INVALID_PLAYER")
  assert(sessions:open(1, "Alice_123"))
end

return tests
