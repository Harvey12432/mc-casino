local sourceRoot = fs.getDir(fs.getDir(shell.getRunningProgram()))
local Installer = dofile(fs.combine(sourceRoot, "installer/lib.lua"))

print("Installing MC Casino server from " .. sourceRoot)
Installer.copyTree(fs.combine(sourceRoot, "src/shared"), "/casino/shared")
Installer.copyTree(fs.combine(sourceRoot, "src/server"), "/casino/server")
Installer.ensureDirectory("/casino/data")

for _, name in ipairs({
  "players.json",
  "transactions.json",
  "jackpots.json",
  "games.json",
  "system.json",
}) do
  Installer.copyFileIfMissing(
    fs.combine(sourceRoot, "data/" .. name),
    "/casino/data/" .. name
  )
end

Installer.copyFileIfMissing(
  fs.combine(sourceRoot, "config.example.lua"),
  "/casino/config.lua"
)

Installer.replaceFilePreserving(
  fs.combine(sourceRoot, "src/server/startup.lua"),
  "/startup.lua",
  "/startup.before-mc-casino.lua"
)

print("Server installed. Edit /casino/config.lua, then reboot.")
print("Live files in /casino/data were preserved.")
if fs.exists("/startup.before-mc-casino.lua") then
  print("Previous startup preserved at /startup.before-mc-casino.lua")
end
