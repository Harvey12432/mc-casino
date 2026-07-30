local validation = require("shared.validation")

local tests = {}

function tests.requests_reject_oversized_or_deep_payloads()
  local oversized = {}
  for index = 1, 129 do oversized[index] = index end
  assert(not validation.isRequest({
    type = "game.create",
    requestId = "large",
    casinoId = "test",
    payload = oversized,
  }))

  local deep = { value = { value = { value = { value = { value = true } } } } }
  assert(not validation.isRequest({
    type = "game.create",
    requestId = "deep",
    casinoId = "test",
    payload = deep,
  }))
end

function tests.requests_accept_normal_game_payloads()
  assert(validation.isRequest({
    type = "game.create",
    requestId = "normal",
    casinoId = "test",
    payload = {
      game = "roulette",
      bet = 5,
      options = { choice = "red" },
    },
  }))
end

function tests.requests_reject_non_finite_nested_numbers()
  assert(not validation.isRequest({
    type = "game.create",
    requestId = "request:infinite",
    casinoId = "main-floor",
    payload = { options = { multiplier = math.huge } },
  }))
  assert(not validation.isRequest({
    type = "game.create",
    requestId = "request:nan",
    casinoId = "main-floor",
    payload = { options = { multiplier = 0 / 0 } },
  }))
end

function tests.requests_reject_malformed_session_tokens()
  assert(not validation.isRequest({
    type = "account.view",
    requestId = "request:bad-token-type",
    casinoId = "main-floor",
    sessionToken = {},
    payload = {},
  }))
  assert(not validation.isRequest({
    type = "account.view",
    requestId = "request:long-token",
    casinoId = "main-floor",
    sessionToken = string.rep("x", 129),
    payload = {},
  }))
end

return tests
