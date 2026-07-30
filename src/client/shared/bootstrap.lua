local bootstrap = {}
local config = require("shared.config")

local function validPlayerName(value)
  return type(value) == "string"
    and #value >= 1
    and #value <= 32
    and value:match("^[A-Za-z0-9_]+$") ~= nil
end

function bootstrap.connect(client)
  while true do
    local callOk, connected, connectError = pcall(client.connect, client)
    if callOk and connected then return true end
    term.clear()
    term.setCursorPos(1, 1)
    printError("WAITING FOR CASINO SERVER")
    print(
      tostring(callOk and connectError or connected)
        .. "\n\nCheck the modem and server. Retrying in 2 seconds."
    )
    sleep(2)
  end
end

function bootstrap.connectAndLogin(client, expectedRole)
  bootstrap.connect(client)

  local playerName = settings.get("casino.player")
  local session
  while not session do
    if not validPlayerName(playerName) then
      term.clear()
      term.setCursorPos(1, 1)
      print("WELCOME TO THE CASINO")
      print("")
      print("Minecraft player name:")
      playerName = read()
      if not validPlayerName(playerName) then
        printError("Use 1-32 letters, numbers, or underscores.")
        sleep(1.5)
        playerName = nil
      else
        settings.set("casino.player", playerName)
        settings.save()
      end
    end
    if playerName then
      local loginError
      session, loginError = client:login(playerName)
      if not session then
        printError(tostring(loginError))
        if tostring(loginError):find("valid player name", 1, true) then
          settings.unset("casino.player")
          settings.save()
          playerName = nil
        else
          sleep(2)
        end
      end
    end
  end

  if expectedRole
    and session.role ~= expectedRole
    and session.role ~= "admin"
  then
    error(("Computer is not authorised as %s"):format(expectedRole))
  end
  if expectedRole == "cashier" then
    local server = client.serverInfo or {}
    if server.currencyItem ~= config.currencyItem
      or server.creditsPerItem ~= config.creditsPerItem
    then
      error(
        "Cashier currency does not match the server. "
          .. ("Server: %s at %s credit(s); cashier: %s at %s credit(s).")
            :format(
              tostring(server.currencyItem),
              tostring(server.creditsPerItem),
              tostring(config.currencyItem),
              tostring(config.creditsPerItem)
            )
      )
    end
  end
  return session
end

return bootstrap
