local tests = {}

local function runBootstrap(role)
  local original = {
    fs = _G.fs,
    http = _G.http,
    shell = _G.shell,
    printError = _G.printError,
  }
  local directories = { ["/"] = true }
  local files = {}
  local requests = {}
  local installerCall

  local function combine(first, second)
    if first == "/" then return "/" .. second end
    return first .. "/" .. second
  end

  _G.fs = {
    combine = combine,
    getDir = function(path)
      return path:match("^(.*)/[^/]+$") or ""
    end,
    getName = function(path) return path:match("([^/]+)$") end,
    exists = function(path)
      return directories[path] == true or files[path] ~= nil
    end,
    makeDir = function(path) directories[path] = true end,
    delete = function(path)
      directories[path] = nil
      files[path] = nil
      local prefix = path .. "/"
      for candidate in pairs(directories) do
        if candidate:sub(1, #prefix) == prefix then directories[candidate] = nil end
      end
      for candidate in pairs(files) do
        if candidate:sub(1, #prefix) == prefix then files[candidate] = nil end
      end
    end,
    open = function(path, mode)
      assert(mode == "w")
      local buffer = ""
      return {
        write = function(value) buffer = buffer .. value end,
        close = function() files[path] = buffer end,
      }
    end,
    copy = function(source, destination)
      assert(files[source] ~= nil, "Missing copy source " .. source)
      files[destination] = files[source]
    end,
  }
  _G.http = {
    get = function(url)
      local path = assert(
        url:match(
          "^https://raw%.githubusercontent%.com/Harvey12432/"
            .. "mc%-casino/main/(.+)$"
        ),
        "Unexpected GitHub URL " .. tostring(url)
      )
      requests[#requests + 1] = path
      return {
        getResponseCode = function() return 200 end,
        readAll = function() return "-- downloaded " .. path end,
        close = function() end,
      }
    end,
  }
  _G.shell = {
    run = function(path, argument)
      installerCall = { path = path, argument = argument }
      return true
    end,
  }
  _G.printError = function() end

  local ok, testError = pcall(function()
    assert(loadfile("bootstrap.lua"))(role)
  end)

  _G.fs = original.fs
  _G.http = original.http
  _G.shell = original.shell
  _G.printError = original.printError
  assert(ok, testError)
  return requests, installerCall, files, directories
end

local function contains(values, wanted)
  for _, value in ipairs(values) do
    if value == wanted then return true end
  end
  return false
end

function tests.github_bootstrap_downloads_and_runs_the_server_installer()
  local requests, installerCall, files, directories = runBootstrap("server")
  assert(contains(requests, "installer/install_server.lua"))
  assert(contains(requests, "installer/setup.lua"))
  assert(contains(requests, "src/server/main.lua"))
  assert(contains(requests, "src/server/games/state_validation.lua"))
  assert(contains(requests, "src/shared/config.lua"))
  assert(contains(requests, "data/players.json"))
  assert(contains(requests, "dev/preflight.lua"))
  assert(not contains(requests, "src/client/shared/components.lua"))
  assert(installerCall.path
    == "/.mc-casino-download/installer/install_server.lua")
  assert(installerCall.argument == nil)
  assert(files["/casino/dev/preflight.lua"]
    == "-- downloaded dev/preflight.lua")
  assert(files["/.mc-casino-download/config.example.lua"] == nil)
  assert(directories["/.mc-casino-download"] == nil)
end

function tests.github_bootstrap_downloads_only_the_requested_terminal_role()
  local requests, installerCall = runBootstrap("blackjack")
  assert(contains(requests, "installer/install_terminal.lua"))
  assert(contains(requests, "installer/setup.lua"))
  assert(contains(requests, "src/client/shared/components.lua"))
  assert(contains(requests, "src/client/blackjack/deck.lua"))
  assert(contains(requests, "src/client/blackjack/game.lua"))
  assert(contains(requests, "src/client/blackjack/ui.lua"))
  assert(contains(requests, "src/shared/config.lua"))
  assert(contains(requests, "dev/preflight.lua"))
  assert(not contains(requests, "src/client/slots/ui.lua"))
  assert(not contains(requests, "src/server/main.lua"))
  assert(not contains(requests, "data/players.json"))
  assert(installerCall.path
    == "/.mc-casino-download/installer/install_terminal.lua")
  assert(installerCall.argument == "blackjack")
end

function tests.github_bootstrap_installs_acceptance_tool_for_admin()
  local requests, installerCall, files = runBootstrap("admin")
  assert(contains(requests, "dev/acceptance.lua"))
  assert(installerCall.argument == "admin")
  assert(files["/casino/dev/acceptance.lua"]
    == "-- downloaded dev/acceptance.lua")
end

return tests
