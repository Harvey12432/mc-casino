local components = require("client.shared.components")
local protocol = require("shared.protocol")

local gameUi = {}

local function humanize(value)
  local text = tostring(value or ""):gsub("_", " ")
  return text:gsub("^%l", string.upper)
end

local function join(values, separator)
  local result = {}
  for _, value in ipairs(values or {}) do result[#result + 1] = tostring(value) end
  return table.concat(result, separator or ", ")
end

local function cards(values)
  local result = {}
  for _, card in ipairs(values or {}) do
    result[#result + 1] = tostring(card.rank) .. tostring(card.suit)
  end
  return table.concat(result, " ")
end

local function describe(result)
  if result.game == "roulette" then
    return ("%s bet | landed %s %s | payout %s"):format(
      humanize(result.choice), tostring(result.number), humanize(result.colour),
      tostring(result.payout))
  elseif result.game == "crash" then
    return ("Multiplier %.2fx | %s"):format(
      (result.multiplier or 100) / 100, result.outcome or "running")
  elseif result.game == "mines" then
    return ("Safe: %s | %.2fx | %s"):format(
      join(result.revealed), result.multiplier or 1, result.outcome or "playing")
  elseif result.game == "plinko" then
    return ("Path %s | bin %s | %sx"):format(
      join(result.path, ""), tostring(result.bin), tostring(result.multiplier))
  elseif result.game == "horse_racing" then
    return ("Picked #%s | winner #%s | payout %s"):format(
      tostring(result.selected), tostring(result.winner), tostring(result.payout))
  elseif result.game == "poker" then
    return ("%s | %s | payout %s"):format(
      cards(result.hand), tostring(result.outcome or "choose holds"),
      tostring(result.payout))
  elseif result.game == "craps" then
    return ("Dice %s = %s | point %s | %s"):format(
      join(result.dice, "+"), tostring(result.total), tostring(result.point or "-"),
      humanize(result.outcome or result.phase))
  elseif result.game == "coin_flip" then
    return ("%s landed | picked %s | payout %s"):format(
      humanize(result.result), humanize(result.choice), tostring(result.payout))
  end
  return humanize(result.outcome or result.phase)
end

function gameUi.run(client, spec)
  local app = components.app(spec.title, "Server-authorised outcomes")
  components.addPlayerSwitch(app, client)
  local current
  local activeGameKey = "casino." .. spec.game .. ".gameId." .. client.player.id
  local selectedOption = spec.choices and spec.choices[1].value or nil
  if spec.rules then
    app.main:addLabel():setText(spec.rules)
      :setPosition(2, 4):setForeground(colors.lightGray)
  end
  local balance = app.main:addLabel():setText(components.playerSummary(client.player))
    :setPosition(2, 5):setForeground(colors.white)
  local resultLabel = app.main:addLabel():setText("Place a bet to begin")
    :setPosition(2, 7):setSize("{parent.width - 3}", 2):setForeground(colors.yellow)
  local bet = app.main:addInput():setPosition(2, 10):setSize(9, 1)
    :setPlaceholder("Bet"):setText(tostring((client.serverInfo or {}).minimumBet or 5))
    :setBackground(colors.gray):setForeground(colors.white)
  local option
  if spec.optionHint then
    option = app.main:addInput():setPosition(13, 10):setSize(16, 1)
      :setPlaceholder(spec.optionHint)
      :setBackground(colors.gray):setForeground(colors.white)
    app.main:addLabel()
      :setText("Exact-number entry overrides the selected button")
      :setPosition(2, 11)
      :setForeground(colors.lightGray)
  end

  local function refreshBalance()
    components.request(app, client, protocol.types.ACCOUNT_VIEW, {}, function(account)
      client.player = account.player
      balance:setText(components.playerSummary(account.player))
    end)
  end

  local function show(result)
    current = result
    if result.phase == "settled" then
      settings.unset(activeGameKey)
    else
      settings.set(activeGameKey, result.gameId)
    end
    settings.save()
    if spec.animate then
      app.busy = true
      spec.animate(result, resultLabel)
      app.busy = false
    end
    local description = describe(result)
    if result.payoutCapped then
      description = description
        .. (" | balance cap: %s of %s credited"):format(
          tostring(result.payout),
          tostring(result.grossPayout)
        )
    end
    resultLabel:setText(description)
    components.setStatus(app, result.phase == "settled"
      and ("Round finished: " .. humanize(result.outcome)) or "Round in progress", false)
    refreshBalance()
  end

  local function optionValue()
    if option and option:getText() ~= "" then return option:getText() end
    return selectedOption
  end

  local choiceButtons = {}
  local function renderChoiceButtons()
    for _, entry in ipairs(choiceButtons) do
      local marker = entry.choice.value == selectedOption and ">" or " "
      entry.button:setText(marker .. entry.choice.text)
    end
  end

  if spec.choices then
    local x = 2
    for _, choice in ipairs(spec.choices) do
      local currentChoice = choice
      local button = app.main:addButton()
        :setPosition(x, 12)
        :setSize(currentChoice.width or 7, 1)
        :setBackground(currentChoice.colour or colors.gray)
        :setForeground(currentChoice.foreground or colors.white)
        :onClick(function()
          selectedOption = currentChoice.value
          if option then option:setText("") end
          renderChoiceButtons()
          components.setStatus(app, "Selected " .. currentChoice.text, false)
        end)
      choiceButtons[#choiceButtons + 1] = {
        button = button,
        choice = currentChoice,
      }
      x = x + (currentChoice.width or 7) + 1
    end
    renderChoiceButtons()
  end

  app.main:addButton():setText(spec.startText or "PLAY"):setPosition(39, 9)
    :setSize(10, 3):setBackground(colors.red):setForeground(colors.white)
    :onClick(function()
      if current and current.phase ~= "settled" then
        return components.setStatus(
          app,
          "Finish the current round before starting another",
          true
        )
      end
      local wager = tonumber(bet:getText())
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
      local value = optionValue()
      components.request(app, client, protocol.types.GAME_CREATE, {
        game=spec.game, bet=wager,
        options=spec.options and spec.options(value) or {},
      }, show)
    end)

  local function refreshCurrent()
    if not current then return end
    components.request(app, client, protocol.types.GAME_VIEW, {
      gameId=current.gameId,
    }, show)
  end

  local function act(actionName, payload)
    if not current or current.phase == "settled" then
      return components.setStatus(app, "Start a round first", true)
    end
    if actionName == "view" then return refreshCurrent() end
    payload = payload or {}
    payload.gameId, payload.action, payload.expectedRevision =
      current.gameId, actionName, current.revision
    components.request(
      app,
      client,
      protocol.types.GAME_ACTION,
      payload,
      show,
      function(_, errorCode)
        if errorCode == "STALE_STATE" then refreshCurrent() end
      end
    )
  end

  if spec.actionButtons then
    local x = 2
    for _, actionSpec in ipairs(spec.actionButtons) do
      local currentAction = actionSpec
      app.main:addButton()
        :setText(currentAction.text)
        :setPosition(currentAction.x or x, currentAction.y or 15)
        :setSize(currentAction.width or 12, 2)
        :setBackground(currentAction.colour or colors.blue)
        :setForeground(currentAction.foreground or colors.white)
        :onClick(function()
          act(
            currentAction.action,
            currentAction.payload and currentAction.payload() or {}
          )
        end)
      if not currentAction.x then
        x = x + (currentAction.width or 12) + 2
      end
    end
  end

  local activeGameId = settings.get(activeGameKey)
  if activeGameId then
    components.request(app, client, protocol.types.GAME_VIEW, {
      gameId = activeGameId,
    }, show, function()
      settings.unset(activeGameKey)
      settings.save()
    end)
  end
  components.run(app)
end

gameUi.numberOption = function(key)
  return function(value) return {[key]=tonumber(value)} end
end
gameUi.stringOption = function(key)
  return function(value) return {[key]=value:lower()} end
end
gameUi.rouletteAnimation = function(_, label)
  for _ = 1, 10 do
    label:setText(("Wheel spinning... %02d"):format(math.random(0, 36)))
    sleep(0.06)
  end
end

gameUi.coinAnimation = function(_, label)
  for index = 1, 8 do
    label:setText(index % 2 == 0 and "        TAILS" or "        HEADS")
    sleep(0.08)
  end
end

gameUi.horseAnimation = function(_, label)
  for _ = 1, 9 do
    label:setText(
      ("Race leader: #%d\n%s"):format(
        math.random(1, 5),
        string.rep(">", math.random(4, 18))
      )
    )
    sleep(0.08)
  end
end

gameUi.plinkoAnimation = function(result, label)
  local shown = ""
  for _, direction in ipairs(result.path or {}) do
    shown = shown .. direction
    label:setText("Dropping...\n" .. shown)
    sleep(0.08)
  end
end

gameUi.diceAnimation = function(_, label)
  for _ = 1, 7 do
    local first, second = math.random(1, 6), math.random(1, 6)
    label:setText(("Rolling dice...\n[ %d ]  [ %d ]"):format(first, second))
    sleep(0.07)
  end
end

return gameUi
