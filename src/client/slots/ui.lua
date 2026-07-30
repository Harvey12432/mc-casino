local components = require("client.shared.components")
local protocol = require("shared.protocol")

local ui = {}

function ui.run(client)
  local app = components.app("CASINO SLOTS", "Server-authorised outcomes")
  components.addPlayerSwitch(app, client)

  local balance = app.main:addLabel()
    :setText(components.playerSummary(client.player))
    :setPosition(2, 4)
    :setForeground(colors.white)

  local jackpot = app.main:addLabel()
    :setText("Progressive jackpot: loading...")
    :setPosition(2, 5)
    :setForeground(colors.lime)

  local reels = app.main:addLabel()
    :setText("[ ? ]  [ ? ]  [ ? ]")
    :setPosition(4, 7)
    :setForeground(colors.yellow)

  local betInput = app.main:addInput()
    :setPosition(2, 10)
    :setSize(10, 1)
    :setPlaceholder("Bet")
    :setText(tostring((client.serverInfo or {}).minimumBet or 5))
    :setBackground(colors.gray)
    :setForeground(colors.white)

  app.main:addButton()
    :setText("SPIN")
    :setPosition(14, 9)
    :setSize(12, 3)
    :setBackground(colors.red)
    :setForeground(colors.white)
    :onClick(function()
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
        game = "slots",
        bet = wager,
      }, function(result)
        app.busy = true
        if result.reels then
          local animationSymbols = { "CHERRY", "LEMON", "BELL", "DIAMOND", "SEVEN" }
          for _ = 1, 8 do
            local frame = {}
            for index = 1, 3 do
              frame[index] = "[ "
                .. animationSymbols[math.random(#animationSymbols)]
                .. " ]"
            end
            reels:setText(table.concat(frame, " "))
            sleep(0.1)
          end
          local shown = {}
          for index, symbol in ipairs(result.reels) do
            shown[index] = "[ " .. symbol:upper() .. " ]"
          end
          reels:setText(table.concat(shown, " "))
        end
        app.busy = false
        components.request(app, client, protocol.types.ACCOUNT_VIEW, {},
          function(account)
            client.player = account.player
            balance:setText(components.playerSummary(account.player))
            components.setStatus(
              app,
              result.payoutCapped
                and ("Balance cap: credited "
                  .. result.payout
                  .. " of "
                  .. result.grossPayout)
                or result.outcome == "win"
                and ("Won " .. result.payout .. " credits!")
                or (result.outcome == "push"
                  and "Pair! Your bet was returned."
                  or "No win this spin"),
              false
            )
            components.request(
              app,
              client,
              protocol.types.DISPLAY_SUBSCRIBE,
              {},
              function(snapshot)
                jackpot:setText(
                  "Progressive jackpot: "
                    .. tostring(snapshot.jackpot or 0)
                    .. " credits"
                )
              end
            )
          end)
      end)
    end)

  app.main:addLabel()
    :setText("PAIR = BET BACK | CHERRY 2x | LEMON 3x")
    :setPosition(2, 13)
    :setForeground(colors.lightGray)
  app.main:addLabel()
    :setText("BELL 5x | DIAMOND 8x | SEVEN 15x + JACKPOT")
    :setPosition(2, 14)
    :setForeground(colors.lightGray)

  components.request(
    app,
    client,
    protocol.types.DISPLAY_SUBSCRIBE,
    {},
    function(snapshot)
      jackpot:setText(
        "Progressive jackpot: "
          .. tostring(snapshot.jackpot or 0)
          .. " credits"
      )
    end
  )

  components.run(app)
end

return ui
