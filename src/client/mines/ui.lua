local components = require("client.shared.components")
local protocol = require("shared.protocol")

local ui = {}

local function contains(values, wanted)
  for _, value in ipairs(values or {}) do
    if value == wanted then return true end
  end
  return false
end

function ui.run(client)
  local app = components.app("CASINO MINES", "Reveal safe tiles, then cash out")
  components.addPlayerSwitch(app, client)
  local current
  local mineCount = 3
  local activeGameKey = "casino.mines.gameId." .. client.player.id

  local balance = app.main:addLabel()
    :setText(components.playerSummary(client.player))
    :setPosition(2, 4)
    :setForeground(colors.white)

  local bet = app.main:addInput()
    :setPosition(2, 5)
    :setSize(8, 1)
    :setPlaceholder("Bet")
    :setText(tostring((client.serverInfo or {}).minimumBet or 5))
    :setBackground(colors.gray)
    :setForeground(colors.white)

  local risk = app.main:addLabel()
    :setText("3 mines")
    :setPosition(12, 5)
    :setForeground(colors.yellow)

  app.main:addLabel()
    :setText("More mines grow the cashout multiplier faster")
    :setPosition(2, 6)
    :setForeground(colors.lightGray)

  local cells = {}
  for position = 1, 25 do
    local cell = position
    local column = (position - 1) % 5
    local row = math.floor((position - 1) / 5)
    cells[position] = app.main:addButton()
      :setText(tostring(position))
      :setPosition(2 + column * 6, 7 + row * 2)
      :setSize(5, 1)
      :setBackground(colors.gray)
      :setForeground(colors.white)
      :onClick(function()
        if not current or current.phase ~= "playing" then
          return components.setStatus(app, "Start a minefield first", true)
        end
        if contains(current.revealed, cell) then
          return components.setStatus(app, "That tile is already safe", false)
        end
        components.request(
          app,
          client,
          protocol.types.GAME_ACTION,
          {
            gameId = current.gameId,
            action = "reveal",
            position = cell,
            expectedRevision = current.revision,
          },
          function(result) ui.render(app, client, result, cells, balance) current = result end,
          function(_, errorCode)
            if errorCode == "STALE_STATE" then
              components.request(app, client, protocol.types.GAME_VIEW, {
                gameId = current.gameId,
              }, function(result)
                ui.render(app, client, result, cells, balance)
                current = result
              end)
            end
          end
        )
      end)
  end

  local difficulties = {
    { count=3, text="CALM", colour=colors.green },
    { count=5, text="RISKY", colour=colors.orange, foreground=colors.black },
    { count=8, text="WILD", colour=colors.red },
  }
  local difficultyX = 32
  for _, difficulty in ipairs(difficulties) do
    local choice = difficulty
    app.main:addButton()
      :setText(choice.text)
      :setPosition(difficultyX, 7)
      :setSize(5, 1)
      :setBackground(choice.colour)
      :setForeground(choice.foreground or colors.white)
      :onClick(function()
        if current and current.phase == "playing" then
          return components.setStatus(app, "Finish this minefield first", true)
        end
        mineCount = choice.count
        risk:setText(tostring(mineCount) .. " mines")
        components.setStatus(app, choice.text .. " risk selected", false)
      end)
    difficultyX = difficultyX + 6
  end

  local function validBet()
    local wager = tonumber(bet:getText())
    local limits = client.serverInfo or {}
    if not wager or wager ~= math.floor(wager)
      or wager < (limits.minimumBet or 1)
      or wager > (limits.maximumBet or math.huge)
    then
      components.setStatus(app, "Enter a whole bet inside the table limits", true)
      return nil
    end
    return wager
  end

  app.main:addButton()
    :setText("START FIELD")
    :setPosition(32, 10)
    :setSize(17, 3)
    :setBackground(colors.red)
    :setForeground(colors.white)
    :onClick(function()
      if current and current.phase == "playing" then
        return components.setStatus(
          app,
          "Cash out or finish this minefield first",
          true
        )
      end
      local wager = validBet()
      if not wager then return end
      components.request(app, client, protocol.types.GAME_CREATE, {
        game = "mines",
        bet = wager,
        options = { mines = mineCount },
      }, function(result)
        current = result
        ui.render(app, client, result, cells, balance)
      end)
    end)

  app.main:addButton()
    :setText("CASH OUT")
    :setPosition(32, 14)
    :setSize(17, 3)
    :setBackground(colors.lime)
    :setForeground(colors.black)
    :onClick(function()
      if not current or current.phase ~= "playing" then
        return components.setStatus(app, "No active minefield", true)
      end
      if (current.revealedCount or 0) < 1 then
        return components.setStatus(app, "Reveal at least 1 safe tile first", true)
      end
      components.request(app, client, protocol.types.GAME_ACTION, {
        gameId = current.gameId,
        action = "cashout",
        expectedRevision = current.revision,
      }, function(result)
        current = result
        ui.render(app, client, result, cells, balance)
      end, function(_, errorCode)
        if errorCode == "STALE_STATE" then
          components.request(app, client, protocol.types.GAME_VIEW, {
            gameId = current.gameId,
          }, function(result)
            current = result
            ui.render(app, client, result, cells, balance)
          end)
        end
      end)
    end)

  local activeGameId = settings.get(activeGameKey)
  if activeGameId then
    components.request(app, client, protocol.types.GAME_VIEW, {
      gameId = activeGameId,
    }, function(result)
      current = result
      ui.render(app, client, result, cells, balance)
    end, function()
      settings.unset(activeGameKey)
      settings.save()
    end)
  end

  components.run(app)
end

function ui.render(app, client, result, cells, balance)
  local activeGameKey = "casino.mines.gameId." .. client.player.id
  if result.phase == "settled" then
    settings.unset(activeGameKey)
  else
    settings.set(activeGameKey, result.gameId)
  end
  settings.save()

  for position, cell in ipairs(cells) do
    if contains(result.mines, position) then
      cell:setText(position == result.hit and "BOOM" or "X")
        :setBackground(colors.red)
    elseif contains(result.revealed, position) then
      cell:setText("SAFE"):setBackground(colors.green)
    else
      cell:setText(tostring(position)):setBackground(colors.gray)
    end
  end

  if result.phase == "settled" then
    components.setStatus(
      app,
      result.payoutCapped
        and ("Balance cap: credited "
          .. result.payout
          .. " of "
          .. result.grossPayout)
        or result.outcome == "lose"
        and "Mine hit. The field has been revealed."
        or ("Cashed out for " .. tostring(result.payout) .. " credits!"),
      result.outcome == "lose" or result.payoutCapped
    )
  else
    components.setStatus(
      app,
      ("%d safe | %.2fx"):format(
        result.revealedCount or 0,
        result.multiplier or 1
      ),
      false
    )
  end
  components.request(app, client, protocol.types.ACCOUNT_VIEW, {}, function(account)
    client.player = account.player
    balance:setText(components.playerSummary(account.player))
  end)
end

return ui
