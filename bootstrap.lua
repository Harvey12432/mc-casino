-- One-command GitHub installer for MC Casino.
-- Usage: wget run <raw GitHub URL>/bootstrap.lua <role>
local role = ({ ... })[1]
local repositoryRoot =
  "https://raw.githubusercontent.com/Harvey12432/mc-casino/main/"
local stagingRoot = "/.mc-casino-download"

local roleFiles = {
  admin = { "main.lua", "startup.lua", "ui.lua" },
  blackjack = { "deck.lua", "game.lua", "main.lua", "startup.lua", "ui.lua" },
  cashier = { "inventory.lua", "main.lua", "startup.lua", "ui.lua" },
  coin_flip = { "main.lua", "startup.lua", "ui.lua" },
  craps = { "main.lua", "startup.lua", "ui.lua" },
  crash = { "main.lua", "startup.lua", "ui.lua" },
  horse_racing = { "main.lua", "startup.lua", "ui.lua" },
  leaderboard = { "main.lua", "startup.lua", "ui.lua" },
  mines = { "main.lua", "startup.lua", "ui.lua" },
  plinko = { "main.lua", "startup.lua", "ui.lua" },
  poker = { "main.lua", "startup.lua", "ui.lua" },
  roulette = { "main.lua", "startup.lua", "ui.lua" },
  slots = { "main.lua", "startup.lua", "ui.lua" },
}

if role ~= "server" and not roleFiles[role] then
  error(
    "Usage: bootstrap <server|admin|blackjack|cashier|coin_flip|craps"
      .. "|crash|horse_racing|leaderboard|mines|plinko|poker|roulette|slots>",
    0
  )
end
if not http or type(http.get) ~= "function" then
  error("The CC:Tweaked HTTP API must be enabled before installation", 0)
end

local sharedFiles = {
  "src/shared/config.lua",
  "src/shared/logger.lua",
  "src/shared/network.lua",
  "src/shared/protocol.lua",
  "src/shared/util.lua",
  "src/shared/validation.lua",
}
local clientSharedFiles = {
  "src/client/shared/bootstrap.lua",
  "src/client/shared/client.lua",
  "src/client/shared/components.lua",
  "src/client/shared/game_ui.lua",
  "src/client/shared/theme.lua",
}
local serverFiles = {
  "src/server/games/blackjack.lua",
  "src/server/games/coin_flip.lua",
  "src/server/games/craps.lua",
  "src/server/games/crash.lua",
  "src/server/games/horse_racing.lua",
  "src/server/games/mines.lua",
  "src/server/games/plinko.lua",
  "src/server/games/poker.lua",
  "src/server/games/roulette.lua",
  "src/server/games/slots.lua",
  "src/server/games/state_validation.lua",
  "src/server/handlers/account_handler.lua",
  "src/server/handlers/admin_handler.lua",
  "src/server/handlers/game_handler.lua",
  "src/server/main.lua",
  "src/server/repositories/game_repository.lua",
  "src/server/repositories/jackpot_repository.lua",
  "src/server/repositories/json_repository.lua",
  "src/server/repositories/player_repository.lua",
  "src/server/repositories/system_repository.lua",
  "src/server/repositories/transaction_repository.lua",
  "src/server/router.lua",
  "src/server/services/account_service.lua",
  "src/server/services/game_service.lua",
  "src/server/services/jackpot_service.lua",
  "src/server/services/session_service.lua",
  "src/server/services/transaction_service.lua",
  "src/server/startup.lua",
}
local seedFiles = {
  "data/games.json",
  "data/jackpots.json",
  "data/players.json",
  "data/system.json",
  "data/transactions.json",
}

local files = {
  "config.example.lua",
  "dev/preflight.lua",
  "installer/lib.lua",
  "installer/setup.lua",
}
local function append(values)
  for _, value in ipairs(values) do files[#files + 1] = value end
end
append(sharedFiles)
if role == "server" then
  files[#files + 1] = "installer/install_server.lua"
  append(seedFiles)
  append(serverFiles)
else
  files[#files + 1] = "installer/install_terminal.lua"
  if role == "admin" then files[#files + 1] = "dev/acceptance.lua" end
  append(clientSharedFiles)
  for _, filename in ipairs(roleFiles[role]) do
    files[#files + 1] = "src/client/" .. role .. "/" .. filename
  end
end

local function download(path, index)
  print(("Downloading %d/%d: %s"):format(index, #files, path))
  local response, requestError = http.get(repositoryRoot .. path)
  if not response then
    error("Download failed for " .. path .. ": " .. tostring(requestError), 0)
  end
  if response.getResponseCode then
    local status = response.getResponseCode()
    if status ~= 200 then
      response.close()
      error(("Download failed for %s: HTTP %s"):format(path, status), 0)
    end
  end
  local contents = response.readAll()
  response.close()
  if type(contents) ~= "string" or contents == "" then
    error("GitHub returned an empty file for " .. path, 0)
  end

  local destination = fs.combine(stagingRoot, path)
  local directory = fs.getDir(destination)
  if directory ~= "" and not fs.exists(directory) then fs.makeDir(directory) end
  local output = assert(fs.open(destination, "w"))
  output.write(contents)
  output.close()
end

if fs.exists(stagingRoot) then fs.delete(stagingRoot) end
fs.makeDir(stagingRoot)

local downloaded, downloadError = pcall(function()
  for index, path in ipairs(files) do download(path, index) end
end)
if not downloaded then
  printError("MC Casino download failed.")
  printError(tostring(downloadError))
  print("The partial download remains at " .. stagingRoot)
  error("Installation stopped before changing /casino", 0)
end

local installerPath = fs.combine(
  stagingRoot,
  role == "server"
    and "installer/install_server.lua"
    or "installer/install_terminal.lua"
)
local installed
if role == "server" then
  installed = shell.run(installerPath)
else
  installed = shell.run(installerPath, role)
end
if not installed then
  error(
    "Installer failed; staged files remain at " .. stagingRoot
      .. " for inspection",
    0
  )
end

local installedTools = { "dev/preflight.lua" }
if role == "admin" then installedTools[#installedTools + 1] = "dev/acceptance.lua" end
if not fs.exists("/casino/dev") then fs.makeDir("/casino/dev") end
for _, path in ipairs(installedTools) do
  local destination = "/casino/dev/" .. fs.getName(path)
  if fs.exists(destination) then fs.delete(destination) end
  fs.copy(fs.combine(stagingRoot, path), destination)
end

fs.delete(stagingRoot)
print(("MC Casino %s installation complete."):format(role))
print("Run /casino/setup.lua whenever you need to change settings.")
