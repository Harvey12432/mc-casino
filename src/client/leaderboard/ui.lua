local components = require("client.shared.components")
local protocol = require("shared.protocol")

local ui = {}

function ui.run(client)
  local app = components.app(
    "CASINO LEADERBOARD",
    "Jackpots and recent wins",
    true
  )

  app.main:addLabel()
    :setText("JACKPOT")
    :setPosition(2, 5)
    :setForeground(colors.yellow)

  local jackpot = app.main:addLabel()
    :setText("Loading...")
    :setPosition(2, 6)
    :setForeground(colors.white)

  app.main:addLabel()
    :setText("LEADERS")
    :setPosition(2, 8)
    :setForeground(colors.lime)

  local leaders = app.main:addLabel()
    :setText("Loading...")
    :setPosition(2, 9)
    :setForeground(colors.white)

  app.main:addLabel()
    :setText("RECENT WINS")
    :setPosition(2, 15)
    :setForeground(colors.yellow)

  local recentWins = app.main:addLabel()
    :setText("Loading...")
    :setPosition(2, 16)
    :setForeground(colors.white)

  local function render(result)
      jackpot:setText(tostring(result.jackpot or 0) .. " credits")
      local lines = {}
      for index, player in ipairs(result.leaders or {}) do
        if index > 5 then break end
        lines[index] = ("%d. %s - %d"):format(
          index,
          player.displayName,
          player.balance
        )
      end
      leaders:setText(#lines > 0 and table.concat(lines, "\n") or "No players")

      local wins = {}
      for index, win in ipairs(result.recentWins or {}) do
        if index > 2 then break end
        wins[index] = ("%s won %d on %s"):format(
          win.playerId,
          win.payout,
          win.game
        )
      end
      recentWins:setText(#wins > 0 and table.concat(wins, "\n") or "No wins yet")
  end

  app.basalt.schedule(function()
    while true do
      local result, refreshError = client:request(
        protocol.types.DISPLAY_SUBSCRIBE,
        {}
      )
      if result then
        render(result)
        components.setStatus(app, "Updated", false)
      else
        components.setStatus(app, refreshError, true)
      end
      sleep(5)
    end
  end)

  components.run(app)
end

return ui
