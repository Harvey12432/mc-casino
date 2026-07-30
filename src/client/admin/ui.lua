local components = require("client.shared.components")
local protocol = require("shared.protocol")

local ui = {}

function ui.run(client)
  local app = components.app("CASINO ADMIN", "Trusted computers only")
  local armedAction
  local armedUntil = 0

  local function confirm(key, message, action)
    local now = os.epoch("utc")
    if armedAction ~= key or now > armedUntil then
      armedAction = key
      armedUntil = now + 10000
      components.setStatus(app, message .. " Press again to confirm.", true)
      return
    end
    armedAction = nil
    armedUntil = 0
    action()
  end

  local profit = app.main:addLabel()
    :setText("House profit: loading...")
    :setPosition(2, 4)
    :setForeground(colors.yellow)

  local results = app.main:addList()
    :setPosition(2, 5)
    :setSize("{parent.width - 3}", 6)
    :setBackground(colors.black)
    :setForeground(colors.white)

  local function showLines(lines)
    results:clear()
    for _, line in ipairs(lines) do results:addItem(line) end
  end

  local actions = {
    { text = "BALANCES", command = "balances", x = 2 },
    { text = "MACHINES", command = "machines", x = 14 },
    { text = "TRANSACTIONS", command = "transactions", x = 26 },
  }

  for _, action in ipairs(actions) do
    local currentAction = action
    app.main:addButton()
      :setText(currentAction.text)
      :setPosition(currentAction.x, 12)
      :setSize(11, 3)
      :setBackground(colors.gray)
      :setForeground(colors.white)
      :onClick(function()
        components.request(app, client, protocol.types.ADMIN_COMMAND, {
          command = currentAction.command,
        }, function(result)
          if currentAction.command == "balances" then
            local lines = {}
            for _, player in ipairs(result.players or {}) do
              table.insert(
                lines,
                ("%s: %d"):format(player.displayName, player.balance)
              )
            end
            showLines(lines)
          elseif currentAction.command == "transactions" then
            local lines = {}
            for _, transaction in ipairs(result.transactions or {}) do
              table.insert(lines, ("%s %s %+d"):format(
                transaction.playerId,
                transaction.kind,
                transaction.amount
              ))
            end
            showLines(lines)
          elseif currentAction.command == "machines" then
            local lines = {}
            for computerId in pairs(result.disabledMachines or {}) do
              table.insert(lines, "Disabled computer " .. computerId)
            end
            table.sort(lines)
            showLines(#lines > 0 and lines or { "No disabled computers" })
          elseif result.houseProfit then
            profit:setText("House profit: " .. result.houseProfit)
            showLines({
              "Jackpot: " .. tostring(result.jackpot),
              "Maintenance: " .. tostring(result.maintenance),
            })
          end
        end)
      end)
  end

  local playerInput = app.main:addInput()
    :setPosition(2, 15)
    :setSize(14, 1)
    :setPlaceholder("Player")
    :setBackground(colors.gray)
    :setForeground(colors.white)

  local amountInput = app.main:addInput()
    :setPosition(18, 15)
    :setSize(9, 1)
    :setPlaceholder("+/- amount")
    :setBackground(colors.gray)
    :setForeground(colors.white)

  app.main:addButton()
    :setText("ADJUST")
    :setPosition(29, 15)
    :setSize(9, 1)
    :setBackground(colors.orange)
    :setForeground(colors.black)
    :onClick(function()
      local playerName = playerInput:getText()
      local amount = tonumber(amountInput:getText())
      if playerName == "" or not amount or amount == 0
        or amount ~= math.floor(amount)
      then
        return components.setStatus(app, "Enter a player and non-zero whole amount", true)
      end
      confirm(
        "adjust:" .. playerName .. ":" .. tostring(amount),
        ("Adjust %s by %+d credits?"):format(playerName, amount),
        function()
          components.request(app, client, protocol.types.ADMIN_COMMAND, {
            command = "adjust",
            player = playerName,
            amount = amount,
          }, function()
            components.setStatus(app, "Balance adjustment committed", false)
          end)
        end
      )
    end)

  app.main:addButton()
    :setText("MAINT ON")
    :setPosition(40, 12)
    :setSize(10, 1)
    :setBackground(colors.red)
    :setForeground(colors.white)
    :onClick(function()
      confirm("maintenance:on", "Pause all new games?", function()
        components.request(app, client, protocol.types.ADMIN_COMMAND, {
          command = "maintenance",
          enabled = true,
        }, function()
          components.setStatus(app, "Maintenance mode is ON", true)
        end)
      end)
    end)

  app.main:addButton()
    :setText("MAINT OFF")
    :setPosition(40, 14)
    :setSize(10, 1)
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(function()
      components.request(app, client, protocol.types.ADMIN_COMMAND, {
        command = "maintenance",
        enabled = false,
      })
    end)

  local machineInput = app.main:addInput()
    :setPosition(40, 15)
    :setSize(10, 1)
    :setPlaceholder("Machine ID")
    :setBackground(colors.gray)
    :setForeground(colors.white)

  local function setMachineDisabled(disabled)
    local computerId = tonumber(machineInput:getText())
    if not computerId or computerId ~= math.floor(computerId) then
      return components.setStatus(app, "Enter a whole-number machine ID", true)
    end
    local function apply()
      components.request(app, client, protocol.types.ADMIN_COMMAND, {
        command = "machine",
        computerId = computerId,
        disabled = disabled,
      }, function()
        components.setStatus(
          app,
          ("Machine %d %s"):format(
            computerId,
            disabled and "disabled" or "enabled"
          ),
          disabled
        )
      end)
    end
    if disabled then
      confirm(
        "disable:" .. tostring(computerId),
        ("Disable machine %d?"):format(computerId),
        apply
      )
    else
      apply()
    end
  end

  app.main:addButton()
    :setText("DISABLE")
    :setPosition(40, 16)
    :setSize(10, 1)
    :setBackground(colors.red)
    :setForeground(colors.white)
    :onClick(function() setMachineDisabled(true) end)

  app.main:addButton()
    :setText("ENABLE")
    :setPosition(40, 17)
    :setSize(10, 1)
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(function() setMachineDisabled(false) end)

  components.request(app, client, protocol.types.ADMIN_COMMAND, {
    command = "summary",
  }, function(result)
    profit:setText("House profit: " .. tostring(result.houseProfit or 0))
  end)

  components.run(app)
end

return ui
