package.path = "src/?.lua;src/?/init.lua;" .. package.path

if not os.epoch then
  function os.epoch()
    return math.floor(os.time() * 1000)
  end
end
if not os.getComputerID then
  function os.getComputerID() return 99 end
end

local writeText = _G.write or function(value) io.write(value) end
local printFailure = _G.printError or print

local suites = {
  "tests.test_blackjack",
  "tests.test_slots",
  "tests.test_accounts",
  "tests.test_game_service",
  "tests.test_sessions",
  "tests.test_json_repository",
  "tests.test_router",
  "tests.test_client",
  "tests.test_cashier_inventory",
  "tests.test_more_games",
  "tests.test_validation",
  "tests.test_installer",
  "tests.test_game_state_validation",
  "tests.test_ui_smoke",
  "tests.test_acceptance",
  "tests.test_preflight",
  "tests.test_github_bootstrap",
  "tests.test_setup",
}

local passed = 0
for _, suiteName in ipairs(suites) do
  local suite = require(suiteName)
  for name, test in pairs(suite) do
    writeText(("%s ... "):format(name))
    local ok, testError = pcall(test)
    if not ok then
      printFailure("FAILED")
      error(testError, 0)
    end
    print("ok")
    passed = passed + 1
  end
end

print(("%d tests passed"):format(passed))
