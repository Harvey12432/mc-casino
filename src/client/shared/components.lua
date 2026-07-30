local theme = require("client.shared.theme")
local config = require("shared.config")
local components = {}

function components.app(title, subtitle, useMonitor)
  local basalt = require("basalt")
  local main
  if useMonitor then
    local monitor = peripheral.wrap(config.monitorSide)
    assert(monitor, "No monitor found on " .. tostring(config.monitorSide))
    main = basalt.createFrame():setTerm(monitor)
  else
    main = basalt.getMainFrame()
  end
  main:setBackground(theme.background)

  main:addLabel()
    :setText(title)
    :setPosition(2, 2)
    :setForeground(theme.primary)

  if subtitle then
    main:addLabel()
      :setText(subtitle)
      :setPosition(2, 3)
      :setForeground(theme.muted)
  end

  local status = main:addLabel()
    :setText("Ready")
    :setPosition(2, "{parent.height - 1}")
    :setForeground(theme.muted)

  return {
    basalt = basalt,
    main = main,
    status = status,
    theme = theme,
  }
end

function components.setStatus(app, message, isError)
  app.status
    :setText(tostring(message))
    :setForeground(isError and theme.danger or theme.muted)
end

function components.playerSummary(player)
  local name = tostring(player.displayName or player.id or "Player")
  if #name > 16 then name = name:sub(1, 15) .. "~" end
  local balance = player.balance or 0
  local amount = balance >= 1000000 and ("%.1fm"):format(balance / 1000000)
    or (balance >= 1000 and ("%.1fk"):format(balance / 1000)
      or tostring(balance))
  return ("%s | %s credits"):format(name, amount)
end

function components.request(app, client, messageType, payload, onSuccess, onError)
  if app.busy then
    components.setStatus(app, "Please wait for the current request", true)
    return false
  end
  app.busy = true
  components.setStatus(app, "Contacting casino server...", false)
  app.basalt.schedule(function()
    local result, requestError, errorCode = client:request(messageType, payload)
    app.busy = false
    if not result then
      components.setStatus(app, requestError, true)
      if onError then onError(requestError, errorCode) end
      return
    end

    components.setStatus(app, "Server request completed", false)
    if onSuccess then
      onSuccess(result)
    end
  end)
  return true
end

function components.addPlayerSwitch(app, client)
  app.main:addButton()
    :setText("CHANGE PLAYER")
    :setPosition("{parent.width - 14}", 2)
    :setSize(13, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)
    :onClick(function()
      if app.busy then
        return components.setStatus(app, "Wait for the current round update", true)
      end
      client:logout()
      settings.unset("casino.player")
      settings.save()
      os.reboot()
    end)
end

function components.run(app)
  app.basalt.run()
end

return components
