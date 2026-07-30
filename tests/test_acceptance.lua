local protocol = require("shared.protocol")

local tests = {}

function tests.in_world_acceptance_script_drives_all_ten_games_and_restores_balance()
  local originalShell = _G.shell
  local originalClientModule = package.loaded["client.shared.client"]
  local originalConfig = package.loaded["shared.config"]

  local balance = 0
  local games = {}
  local nextGame = 0
  local client = {}

  function client:connect() return true end
  function client:login()
    return { role = "admin" }
  end
  function client:request(messageType, payload)
    if messageType == protocol.types.ACCOUNT_VIEW then
      return {
        player = {
          id = "casino_test",
          displayName = "casino_test",
          balance = balance,
        },
      }
    elseif messageType == protocol.types.ADMIN_COMMAND then
      if payload.command == "adjust" then
        balance = balance + payload.amount
        return { adjusted = true }
      elseif payload.command == "summary" then
        return { houseProfit = 0, jackpot = 0 }
      end
    elseif messageType == protocol.types.GAME_CREATE then
      assert(payload.acceptanceTest == true)
      nextGame = nextGame + 1
      balance = balance - payload.bet
      local interactive = {
        blackjack = true,
        crash = true,
        mines = true,
        poker = true,
        craps = true,
      }
      local phase = interactive[payload.game]
        and (payload.game == "mines" and "playing"
          or payload.game == "poker" and "draw"
          or payload.game == "craps" and "point"
          or payload.game == "crash" and "running"
          or "player_turn")
        or "settled"
      local game = {
        game = payload.game,
        gameId = "acceptance:" .. nextGame,
        revision = 1,
        phase = phase,
      }
      games[game.gameId] = game
      return game
    elseif messageType == protocol.types.GAME_ACTION then
      local game = assert(games[payload.gameId])
      assert(payload.expectedRevision == game.revision)
      game.revision = game.revision + 1
      if game.game == "mines" and payload.action == "reveal" then
        game.phase = "playing"
      else
        game.phase = "settled"
      end
      return game
    end
    return nil, "Unexpected acceptance request"
  end

  _G.shell = { setDir = function() end }
  package.loaded["client.shared.client"] = {
    new = function() return client end,
  }
  package.loaded["shared.config"] = {
    acceptancePlayerId = "casino_test",
    minimumBet = 5,
  }

  local ok, testError = pcall(function()
    local acceptance = assert(loadfile("dev/acceptance.lua"))
    acceptance()
  end)

  _G.shell = originalShell
  package.loaded["client.shared.client"] = originalClientModule
  package.loaded["shared.config"] = originalConfig

  assert(ok, testError)
  assert(nextGame == 10)
  assert(balance == 0)
end

return tests
