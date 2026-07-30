local validRoles = {
  cashier = true,
  slots = true,
  blackjack = true,
  leaderboard = true,
  admin = true,
  roulette = true,
  crash = true,
  mines = true,
  plinko = true,
  horse_racing = true,
  poker = true,
  craps = true,
  coin_flip = true,
}

local role = ({ ... })[1]
if not validRoles[role] then
  error(
    "Usage: install_terminal <cashier|slots|blackjack|roulette|crash|mines"
      .. "|plinko|horse_racing|poker|craps|coin_flip|leaderboard|admin>"
  )
end

local sourceRoot = fs.getDir(fs.getDir(shell.getRunningProgram()))
local Installer = dofile(fs.combine(sourceRoot, "installer/lib.lua"))
local basaltVersion = "2.5+a01ea6d577c92fcf76b5689f89eaf2920d011b82"
local basaltExpectedBytes = 277062
local basaltDownloadUrl =
  "https://raw.githubusercontent.com/Pyroxenium/Basalt2/"
  .. "a01ea6d577c92fcf76b5689f89eaf2920d011b82"
  .. "/bundle/basalt.lua"

print(("Installing MC Casino %s client from %s"):format(role, sourceRoot))
Installer.ensureDirectory("/casino")

local installedBasaltVersion
if fs.exists("/casino/basalt.version") then
  local versionFile = fs.open("/casino/basalt.version", "r")
  if versionFile then
    installedBasaltVersion = versionFile.readAll()
    versionFile.close()
  end
end

if not fs.exists("/casino/basalt.lua")
  or installedBasaltVersion ~= basaltVersion
then
  print("Installing pinned Basalt " .. basaltVersion .. "...")
  local response, downloadError = http.get(basaltDownloadUrl)
  if not response then
    error(
      "Basalt download failed; ensure HTTP is enabled: "
        .. tostring(downloadError)
    )
  end
  local contents = response.readAll()
  response.close()
  if #contents ~= basaltExpectedBytes then
    error(
      ("Downloaded Basalt has %d bytes; expected %d. Existing files were not changed.")
        :format(#contents, basaltExpectedBytes)
    )
  end
  local compiled, compileError = load(
    contents,
    "@/casino/basalt.lua",
    "t",
    _ENV
  )
  if not compiled then error("Downloaded Basalt is invalid: " .. compileError) end
  local temporaryBasalt = "/casino/basalt.lua.new"
  if fs.exists(temporaryBasalt) then fs.delete(temporaryBasalt) end
  local target = fs.open(temporaryBasalt, "w")
  if not target then error("Unable to create /casino/basalt.lua") end
  target.write(contents)
  target.close()
  if fs.exists("/casino/basalt.lua") then fs.delete("/casino/basalt.lua") end
  fs.move(temporaryBasalt, "/casino/basalt.lua")
  local temporaryVersion = "/casino/basalt.version.new"
  if fs.exists(temporaryVersion) then fs.delete(temporaryVersion) end
  local versionFile = fs.open(temporaryVersion, "w")
  if not versionFile then error("Unable to create /casino/basalt.version") end
  versionFile.write(basaltVersion)
  versionFile.close()
  if fs.exists("/casino/basalt.version") then fs.delete("/casino/basalt.version") end
  fs.move(temporaryVersion, "/casino/basalt.version")
end

-- Do not modify the installed application until its external dependency is
-- present and verified.
Installer.copyTree(fs.combine(sourceRoot, "src/shared"), "/casino/shared")
Installer.copyTree(fs.combine(sourceRoot, "src/client/shared"), "/casino/client/shared")
Installer.copyTree(
  fs.combine(sourceRoot, "src/client/" .. role),
  "/casino/client/" .. role
)
Installer.copyFileIfMissing(
  fs.combine(sourceRoot, "config.example.lua"),
  "/casino/config.lua"
)

Installer.replaceFilePreserving(
  fs.combine(sourceRoot, "src/client/" .. role .. "/startup.lua"),
  "/startup.lua",
  "/startup.before-mc-casino.lua"
)

print(("The %s client is installed. Edit /casino/config.lua, then reboot."):format(role))
if fs.exists("/startup.before-mc-casino.lua") then
  print("Previous startup preserved at /startup.before-mc-casino.lua")
end
