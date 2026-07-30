local tests = {}

local function environment()
  local files = {}
  local directories = { ["/"] = true, ["/data"] = true }
  local encoded = {}
  local nextToken = 0
  local control = {}

  _G.fs = {
    exists = function(path) return files[path] ~= nil or directories[path] == true end,
    getDir = function(path) return path:match("^(.*)/[^/]+$") or "" end,
    makeDir = function(path) directories[path] = true end,
    delete = function(path) files[path] = nil end,
    move = function(from, to)
      if control.failMoveTo == to then error("simulated move failure") end
      assert(files[from] ~= nil, "Missing source " .. from)
      files[to] = files[from]
      files[from] = nil
    end,
    copy = function(from, to)
      assert(files[from] ~= nil, "Missing source " .. from)
      files[to] = files[from]
    end,
    open = function(path, mode)
      if mode == "r" then
        if files[path] == nil then return nil end
        return {
          readAll = function() return files[path] end,
          close = function() end,
        }
      end
      local buffer = ""
      return {
        write = function(value) buffer = buffer .. value end,
        close = function() files[path] = buffer end,
      }
    end,
  }

  local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
  end

  _G.textutils = {
    serializeJSON = function(value)
      nextToken = nextToken + 1
      local token = "json:" .. nextToken
      encoded[token] = copy(value)
      return token
    end,
    unserializeJSON = function(value)
      return encoded[value] and copy(encoded[value]) or nil
    end,
  }

  return files, control
end

function tests.repository_recovers_the_previous_valid_snapshot()
  local files = environment()
  package.loaded["server.repositories.json_repository"] = nil
  local JsonRepository = require("server.repositories.json_repository")
  local repo = JsonRepository.new("/data/state.json", { balance = 10 })
  assert(repo:load().balance == 10)
  repo:get().balance = 20
  repo:save()
  repo:get().balance = 30
  repo:save()

  files["/data/state.json"] = "corrupt"
  local recovered = JsonRepository.new("/data/state.json", { balance = 0 })
  assert(recovered:load().balance == 20)
  assert(recovered:get().balance == 20)

  files["/data/state.json"] = "corrupt-again"
  local recoveredAgain = JsonRepository.new("/data/state.json", { balance = 0 })
  assert(recoveredAgain:load().balance == 20)
end

function tests.failed_repository_update_rolls_back_memory()
  environment()
  package.loaded["server.repositories.json_repository"] = nil
  local JsonRepository = require("server.repositories.json_repository")
  local repo = JsonRepository.new(
    "/data/limited.json",
    { balance = 10 },
    function(value) return value.balance <= 20 end
  )
  assert(repo:load().balance == 10)
  local ok = pcall(repo.update, repo, function(candidate)
    candidate.balance = 30
  end)
  assert(ok == false)
  assert(repo:get().balance == 10)
end

function tests.failed_disk_commit_preserves_memory_and_recoverable_backup()
  local _, control = environment()
  package.loaded["server.repositories.json_repository"] = nil
  local JsonRepository = require("server.repositories.json_repository")
  local repo = JsonRepository.new("/data/state.json", { balance = 10 })
  assert(repo:load().balance == 10)

  control.failMoveTo = "/data/state.json"
  local ok = pcall(repo.update, repo, function(candidate)
    candidate.balance = 20
  end)
  assert(ok == false)
  assert(repo:get().balance == 10)

  control.failMoveTo = nil
  local recovered = JsonRepository.new("/data/state.json", { balance = 0 })
  assert(recovered:load().balance == 10)
end

function tests.missing_live_file_with_corrupt_backup_fails_closed()
  local files = environment()
  package.loaded["server.repositories.json_repository"] = nil
  local JsonRepository = require("server.repositories.json_repository")
  files["/data/state.json.bak"] = "corrupt"

  local repo = JsonRepository.new("/data/state.json", { balance = 0 })
  local ok = pcall(repo.load, repo)
  assert(ok == false)
  assert(files["/data/state.json"] == nil)
  assert(files["/data/state.json.bak"] == "corrupt")
end

function tests.jackpot_contribution_and_claim_are_idempotent()
  environment()
  package.loaded["server.repositories.json_repository"] = nil
  package.loaded["server.repositories.jackpot_repository"] = nil
  local JackpotRepository = require("server.repositories.jackpot_repository")
  local jackpots = JackpotRepository.new("/data/jackpots.json")

  jackpots:process("spin-1", "slots", 5, false)
  jackpots:process("spin-1", "slots", 5, false)
  assert(jackpots:get("slots") == 5)

  local won = jackpots:process("spin-2", "slots", 1, true)
  local replay = jackpots:process("spin-2", "slots", 1, true)
  assert(won.claimed == 6)
  assert(replay.claimed == 6)
  assert(jackpots:get("slots") == 0)
end

function tests.machine_disable_state_persists()
  environment()
  package.loaded["server.repositories.json_repository"] = nil
  package.loaded["server.repositories.system_repository"] = nil
  local SystemRepository = require("server.repositories.system_repository")
  local stateRepository = SystemRepository.new("/data/system.json")
  local state = stateRepository:get()
  state.disabledMachines["42"] = true
  stateRepository:save(state)

  local reloaded = SystemRepository.new("/data/system.json")
  assert(reloaded:get().disabledMachines["42"] == true)
end

function tests.game_repository_rejects_malformed_game_records()
  environment()
  package.loaded["server.repositories.json_repository"] = nil
  package.loaded["server.repositories.game_repository"] = nil
  local GameRepository = require("server.repositories.game_repository")
  local games = GameRepository.new("/data/games.json")
  local ok = pcall(games.save, games, {
    id = "game:bad",
    createRequestId = "request:bad",
    playerId = "alice",
    senderId = 4,
    type = "mines",
    bet = 5,
    status = "ready",
    revision = 1,
    createdAt = 1,
    settled = false,
    state = {
      phase = "playing",
      bet = 5,
      payout = 0,
      -- Generic fields are insufficient; Mines requires its hidden map,
      -- revealed map, count, and multiplier.
    },
  })
  assert(ok == false)
  assert(games:get("game:bad") == nil)
end

function tests.game_repository_accepts_engine_state_and_public_response()
  environment()
  package.loaded["server.repositories.json_repository"] = nil
  package.loaded["server.repositories.game_repository"] = nil
  local GameRepository = require("server.repositories.game_repository")
  local slots = require("server.games.slots")
  local games = GameRepository.new("/data/games.json")
  local state = slots.spin(5)
  local game = {
    id = "game:slots",
    createRequestId = "request:slots",
    playerId = "alice",
    senderId = 4,
    type = "slots",
    bet = 5,
    options = {},
    status = "ready",
    revision = 1,
    createdAt = 1,
    settled = true,
    settledAt = 2,
    state = state,
  }
  assert(games:save(game))
  local view = slots.view(game)
  assert(games:saveResponse("response:slots", view))
  assert(games:get("game:slots").state.reels[1] == state.reels[1])
  assert(games:getResponse("response:slots").game == "slots")
end

function tests.failed_player_commit_cannot_change_balance_or_create_transaction()
  local _, control = environment()
  package.loaded["server.repositories.json_repository"] = nil
  package.loaded["server.repositories.player_repository"] = nil
  package.loaded["server.repositories.transaction_repository"] = nil
  package.loaded["server.services.transaction_service"] = nil
  package.loaded["server.services.account_service"] = nil

  local originalOs = _G.os
  _G.os = {
    epoch = function() return 1000 end,
  }

  local PlayerRepository = require("server.repositories.player_repository")
  local TransactionRepository = require("server.repositories.transaction_repository")
  local TransactionService = require("server.services.transaction_service")
  local AccountService = require("server.services.account_service")
  local players = PlayerRepository.new("/data/players.json")
  local transactions = TransactionRepository.new("/data/transactions.json")
  local accounts = AccountService.new(
    players,
    TransactionService.new(transactions),
    100,
    1000
  )

  local testOk, testError = pcall(function()
    assert(accounts:getOrCreate("Alice").balance == 100)
    control.failMoveTo = "/data/players.json"
    local ok = pcall(
      accounts.change,
      accounts,
      "request-1",
      "alice",
      10,
      "test_credit",
      "reference-1"
    )

    assert(ok == false)
    assert(accounts:get("alice").balance == 100)
    assert(#transactions:all() == 0)
  end)
  _G.os = originalOs
  assert(testOk, testError)
end

function tests.transaction_repository_rejects_duplicate_request_ids()
  environment()
  package.loaded["server.repositories.json_repository"] = nil
  package.loaded["server.repositories.transaction_repository"] = nil
  local TransactionRepository = require("server.repositories.transaction_repository")
  local transactions = TransactionRepository.new("/data/transactions.json")
  local transaction = {
    id = "txn:request-1",
    requestId = "request-1",
    playerId = "alice",
    kind = "test",
    amount = 5,
    balanceAfter = 5,
    referenceId = "reference-1",
    timestamp = 1000,
  }
  assert(transactions:append(transaction))
  local ok = pcall(transactions.append, transactions, transaction)
  assert(ok == false)
  assert(#transactions:all() == 1)
end

return tests
