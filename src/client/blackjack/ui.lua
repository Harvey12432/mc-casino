local components = require("client.shared.components")
local protocol = require("shared.protocol")
local deck = require("client.blackjack.deck")

local ui = {}

function ui.run(client, game)
  local app = components.app("BLACKJACK", "Dealer stands on soft 17")
  components.addPlayerSwitch(app, client)
  local activeGameKey = "casino.blackjack.gameId." .. client.player.id

  local dealer = app.main:addLabel()
    :setText("Dealer: --")
    :setPosition(2, 6)
    :setForeground(colors.white)

  local player = app.main:addLabel()
    :setText("Player: --")
    :setPosition(2, 9)
    :setForeground(colors.white)

  local balance = app.main:addLabel()
    :setText(components.playerSummary(client.player))
    :setPosition(2, 4)
    :setForeground(colors.white)

  app.main:addLabel()
    :setText("Blackjack 3:2 | win 2x | push returns your bet")
    :setPosition(2, 5)
    :setForeground(colors.lightGray)

  local betInput = app.main:addInput()
    :setPosition(2, 11)
    :setSize(8, 1)
    :setPlaceholder("Bet")
    :setText(tostring((client.serverInfo or {}).minimumBet or 5))
    :setBackground(colors.gray)
    :setForeground(colors.white)

  local function render(view)
    game.applyServerView(game, view)
    if view.phase == "settled" then
      settings.unset(activeGameKey)
    else
      settings.set(activeGameKey, view.gameId)
    end
    settings.save()
    dealer:setText("Dealer: " .. deck.handLabel(view.dealerCards))
    player:setText(
      "Player: " .. deck.handLabel(view.playerCards)
        .. " (" .. tostring(view.playerTotal) .. ")"
    )
    components.setStatus(
      app,
      view.payoutCapped
        and ("Balance cap: credited "
          .. view.payout
          .. " of "
          .. view.grossPayout)
        or view.phase == "settled"
        and ("Result: " .. tostring(view.outcome) .. ", payout " .. view.payout)
        or "Choose an action",
      false
    )
    if view.phase == "settled" then
      components.request(app, client, protocol.types.ACCOUNT_VIEW, {},
        function(account)
          client.player = account.player
          balance:setText(components.playerSummary(account.player))
        end)
    end
  end

  local function act(action)
    if not game.gameId or game.phase == "idle" or game.phase == "settled" then
      return components.setStatus(app, "Deal a new hand first", true)
    end
    local available = false
    for _, name in ipairs(game.actions or {}) do
      if name == action then available = true break end
    end
    if not available then
      return components.setStatus(app, action:upper() .. " is not available", true)
    end
    components.request(app, client, protocol.types.GAME_ACTION, {
      gameId = game.gameId,
      action = action,
      expectedRevision = game.revision,
    }, render, function(_, errorCode)
      if errorCode == "STALE_STATE" and game.gameId then
        components.request(app, client, protocol.types.GAME_VIEW, {
          gameId = game.gameId,
        }, render)
      end
    end)
  end

  app.main:addButton()
    :setText("HIT")
    :setPosition(2, 12)
    :setSize(8, 3)
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(function() act("hit") end)

  app.main:addButton()
    :setText("STAND")
    :setPosition(12, 12)
    :setSize(9, 3)
    :setBackground(colors.red)
    :setForeground(colors.white)
    :onClick(function() act("stand") end)

  app.main:addButton()
    :setText("DOUBLE")
    :setPosition(23, 12)
    :setSize(9, 3)
    :setBackground(colors.blue)
    :setForeground(colors.white)
    :onClick(function() act("double") end)

  app.main:addButton()
    :setText("NEW HAND")
    :setPosition(34, 12)
    :setSize(12, 3)
    :setBackground(colors.orange)
    :setForeground(colors.black)
    :onClick(function()
      if game.gameId and game.phase ~= "idle" and game.phase ~= "settled" then
        return components.setStatus(
          app,
          "Finish the current hand before dealing again",
          true
        )
      end
      local wager = tonumber(betInput:getText())
      local limits = client.serverInfo or {}
      if not wager or wager ~= math.floor(wager)
        or wager < (limits.minimumBet or 1)
        or wager > (limits.maximumBet or math.huge)
      then
        return components.setStatus(
          app,
          ("Enter a whole bet from %s to %s"):format(
            tostring(limits.minimumBet or 1),
            tostring(limits.maximumBet or "the table limit")
          ),
          true
        )
      end
      components.request(app, client, protocol.types.GAME_CREATE, {
        game = "blackjack",
        bet = wager,
      }, render)
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
