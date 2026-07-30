local components = require("client.shared.components")
local protocol = require("shared.protocol")

local ui = {}

function ui.run(client)
  local app = components.app("CASINO CRASH", "Cash out before the line breaks")
  components.addPlayerSwitch(app, client)
  local current
  local watching = false
  local activeGameKey = "casino.crash.gameId." .. client.player.id

  local balance = app.main:addLabel()
    :setText(components.playerSummary(client.player))
    :setPosition(2, 4)
    :setForeground(colors.white)
  app.main:addLabel()
    :setText("Cashout = bet x multiplier | wait longer, risk more")
    :setPosition(2, 5)
    :setForeground(colors.lightGray)
  local multiplier = app.main:addLabel()
    :setText("1.00x")
    :setPosition(20, 7)
    :setForeground(colors.lime)
  local meter = app.main:addLabel()
    :setText("[                    ]")
    :setPosition(15, 9)
    :setForeground(colors.green)
  local bet = app.main:addInput()
    :setPosition(2, 6)
    :setSize(10, 1)
    :setPlaceholder("Bet")
    :setText(tostring((client.serverInfo or {}).minimumBet or 5))
    :setBackground(colors.gray)
    :setForeground(colors.white)

  local startWatching

  local function refreshBalance()
    components.request(app, client, protocol.types.ACCOUNT_VIEW, {}, function(account)
      client.player = account.player
      balance:setText(components.playerSummary(account.player))
    end)
  end

  local function render(result)
    local wasEmpty = current == nil
    current = result
    local value = (result.multiplier or 100) / 100
    multiplier:setText(("%.2fx"):format(value))
    local filled = math.min(20, math.max(1, math.floor((value - 1) * 5) + 1))
    meter:setText("[" .. string.rep("=", filled) .. string.rep(" ", 20 - filled) .. "]")
    local danger = value >= 3 and colors.red
      or (value >= 2 and colors.orange or colors.lime)
    multiplier:setForeground(danger)
    meter:setForeground(danger)

    if result.phase == "settled" then
      settings.unset(activeGameKey)
      if result.payoutCapped then
        components.setStatus(
          app,
          ("Balance cap: credited %d of %d"):format(
            result.payout,
            result.grossPayout
          ),
          true
        )
      elseif result.outcome == "cashout" then
        components.setStatus(
          app,
          ("Cashed out at %.2fx for %d credits!"):format(value, result.payout),
          false
        )
      else
        components.setStatus(
          app,
          ("CRASHED at %.2fx"):format((result.crashPoint or 100) / 100),
          true
        )
      end
    else
      settings.set(activeGameKey, result.gameId)
      components.setStatus(app, "The multiplier is climbing...", false)
      startWatching()
    end
    settings.save()
    if wasEmpty or result.phase == "settled" then refreshBalance() end
  end

  startWatching = function()
    if watching then return end
    watching = true
    app.basalt.schedule(function()
      while current and current.phase == "running" do
        sleep(0.5)
        if not app.busy then
          app.busy = true
          local result, requestError = client:request(
            protocol.types.GAME_VIEW,
            { gameId = current.gameId }
          )
          app.busy = false
          if result then
            render(result)
          else
            components.setStatus(
              app,
              tostring(requestError) .. " Retrying...",
              true
            )
          end
        end
      end
      watching = false
    end)
  end

  app.main:addButton()
    :setText("START RUN")
    :setPosition(2, 9)
    :setSize(11, 3)
    :setBackground(colors.red)
    :setForeground(colors.white)
    :onClick(function()
      if current and current.phase == "running" then
        return components.setStatus(
          app,
          "Cash out or wait for this run to finish",
          true
        )
      end
      local wager = tonumber(bet:getText())
      local limits = client.serverInfo or {}
      if not wager or wager ~= math.floor(wager)
        or wager < (limits.minimumBet or 1)
        or wager > (limits.maximumBet or math.huge)
      then
        return components.setStatus(app, "Enter a whole bet inside the table limits", true)
      end
      components.request(app, client, protocol.types.GAME_CREATE, {
        game = "crash",
        bet = wager,
        options = {},
      }, render)
    end)

  app.main:addButton()
    :setText("CASH OUT NOW")
    :setPosition(15, 12)
    :setSize(22, 4)
    :setBackground(colors.lime)
    :setForeground(colors.black)
    :onClick(function()
      if not current or current.phase ~= "running" then
        return components.setStatus(app, "Start a run first", true)
      end
      components.request(app, client, protocol.types.GAME_ACTION, {
        gameId = current.gameId,
        action = "cashout",
        expectedRevision = current.revision,
      }, render, function(_, errorCode)
        if errorCode == "STALE_STATE" then
          components.request(app, client, protocol.types.GAME_VIEW, {
            gameId = current.gameId,
          }, render)
        end
      end)
    end)

  local activeGameId = settings.get(activeGameKey)
  if activeGameId then
    components.request(app, client, protocol.types.GAME_VIEW, {
      gameId = activeGameId,
    }, render, function()
      settings.unset(activeGameKey)
      settings.save()
    end)
  end

  components.run(app)
end

return ui
