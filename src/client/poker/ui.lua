local components = require("client.shared.components")
local protocol = require("shared.protocol")

local ui = {}

local function cardLabel(card)
  if not card then return "?" end
  return tostring(card.rank) .. tostring(card.suit)
end

function ui.run(client)
  local app = components.app("VIDEO POKER", "Jacks or Better")
  components.addPlayerSwitch(app, client)
  local current
  local held = {}
  local activeGameKey = "casino.poker.gameId." .. client.player.id

  local balance = app.main:addLabel()
    :setText(components.playerSummary(client.player))
    :setPosition(2, 4)
    :setForeground(colors.white)
  local bet = app.main:addInput()
    :setPosition(2, 5)
    :setSize(9, 1)
    :setPlaceholder("Bet")
    :setText(tostring((client.serverInfo or {}).minimumBet or 5))
    :setBackground(colors.gray)
    :setForeground(colors.white)
  app.main:addLabel()
    :setText("Royal 250x | SF 50x | 4K 25x | FH 9x | F 6x")
    :setPosition(2, 6)
    :setForeground(colors.lightGray)

  local cards = {}
  for index = 1, 5 do
    local cardIndex = index
    cards[index] = app.main:addButton()
      :setText("?")
      :setPosition(2 + (index - 1) * 10, 8)
      :setSize(8, 3)
      :setBackground(colors.white)
      :setForeground(colors.black)
      :onClick(function()
        if not current or current.phase ~= "draw" then
          return components.setStatus(app, "Deal a hand first", true)
        end
        held[cardIndex] = not held[cardIndex]
        ui.renderCards(current, cards, held)
        components.setStatus(
          app,
          held[cardIndex] and ("Holding card " .. cardIndex)
            or ("Released card " .. cardIndex),
          false
        )
      end)
  end

  local function render(result)
    current = result
    if result.phase == "settled" then
      settings.unset(activeGameKey)
    else
      settings.set(activeGameKey, result.gameId)
    end
    settings.save()
    ui.renderCards(result, cards, held)
    if result.phase == "settled" then
      components.setStatus(
        app,
        result.payoutCapped
          and ("Balance cap: credited "
            .. result.payout
            .. " of "
            .. result.grossPayout)
          or result.payout > 0
          and (tostring(result.outcome) .. "! Won " .. result.payout .. " credits")
          or "No paying hand",
        result.payout == 0
      )
    else
      components.setStatus(app, "Select cards to HOLD, then draw", false)
    end
    components.request(app, client, protocol.types.ACCOUNT_VIEW, {}, function(account)
      client.player = account.player
      balance:setText(components.playerSummary(account.player))
    end)
  end

  app.main:addButton()
    :setText("DEAL")
    :setPosition(13, 4)
    :setSize(10, 3)
    :setBackground(colors.red)
    :setForeground(colors.white)
    :onClick(function()
      if current and current.phase == "draw" then
        return components.setStatus(
          app,
          "Draw the current hand before dealing again",
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
      held = {}
      components.request(app, client, protocol.types.GAME_CREATE, {
        game = "poker",
        bet = wager,
        options = {},
      }, render)
    end)

  app.main:addButton()
    :setText("DRAW UNHELD CARDS")
    :setPosition(15, 13)
    :setSize(21, 3)
    :setBackground(colors.blue)
    :setForeground(colors.white)
    :onClick(function()
      if not current or current.phase ~= "draw" then
        return components.setStatus(app, "Deal a hand first", true)
      end
      local selected = {}
      for index = 1, 5 do
        if held[index] then table.insert(selected, index) end
      end
      components.request(app, client, protocol.types.GAME_ACTION, {
        gameId = current.gameId,
        action = "draw",
        held = selected,
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

function ui.renderCards(game, buttons, held)
  for index, button in ipairs(buttons) do
    local label = cardLabel((game.hand or {})[index])
    if held[index] then
      button:setText(label .. " HOLD")
        :setBackground(colors.yellow)
        :setForeground(colors.black)
    else
      button:setText(label)
        :setBackground(colors.white)
        :setForeground(colors.black)
    end
  end
end

return ui
