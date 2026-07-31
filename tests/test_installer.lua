local tests = {}

function tests.startup_replacement_preserves_the_first_existing_program()
  local originalFs = _G.fs
  local files = {
    ["/package/startup.lua"] = "casino-v1",
    ["/startup.lua"] = "existing-program",
  }
  _G.fs = {
    exists = function(path) return files[path] ~= nil end,
    copy = function(source, destination)
      assert(files[source] ~= nil, "missing source " .. source)
      files[destination] = files[source]
    end,
    delete = function(path) files[path] = nil end,
  }
  package.loaded["installer.lib"] = nil
  local Installer = require("installer.lib")

  local ok, testError = pcall(function()
    Installer.replaceFilePreserving(
      "/package/startup.lua",
      "/startup.lua",
      "/startup.before-mc-casino.lua"
    )
    assert(files["/startup.lua"] == "casino-v1")
    assert(files["/startup.before-mc-casino.lua"] == "existing-program")

    files["/package/startup.lua"] = "casino-v2"
    Installer.replaceFilePreserving(
      "/package/startup.lua",
      "/startup.lua",
      "/startup.before-mc-casino.lua"
    )
    assert(files["/startup.lua"] == "casino-v2")
    assert(files["/startup.before-mc-casino.lua"] == "existing-program")
  end)

  _G.fs = originalFs
  package.loaded["installer.lib"] = nil
  assert(ok, testError)
end

function tests.terminal_installer_stages_basalt_and_preserves_local_files_on_update()
  local original = {
    fs = _G.fs,
    http = _G.http,
    shell = _G.shell,
  }
  local files = {
    ["src/shared/config.lua"] = "shared-config",
    ["src/shared/protocol.lua"] = "shared-protocol",
    ["src/client/shared/components.lua"] = "shared-components",
    ["src/client/slots/main.lua"] = "slots-main-v1",
    ["src/client/slots/startup.lua"] = "slots-startup-v1",
    ["src/client/slots/ui.lua"] = "slots-ui-v1",
    ["installer/setup.lua"] = "setup-wizard",
    ["config.example.lua"] = "example-config",
    ["/casino/config.lua"] = "local-config",
    ["/startup.lua"] = "existing-startup",
  }
  local directories = {
    [""] = true,
    ["src"] = true,
    ["src/shared"] = true,
    ["src/client"] = true,
    ["src/client/shared"] = true,
    ["src/client/slots"] = true,
    ["installer"] = true,
    ["/"] = true,
    ["/casino"] = true,
  }
  local downloads = 0
  local setupRuns = {}

  local function combine(first, second)
    if first == "" then return second end
    if first == "/" then return "/" .. second end
    return first .. "/" .. second
  end

  _G.fs = {
    combine = combine,
    getDir = function(path)
      return path:match("^(.*)/[^/]+$") or ""
    end,
    exists = function(path)
      return files[path] ~= nil or directories[path] == true
    end,
    isDir = function(path) return directories[path] == true end,
    makeDir = function(path) directories[path] = true end,
    list = function(path)
      local found = {}
      local prefix = path == "" and "" or path .. "/"
      for candidate in pairs(directories) do
        if candidate:sub(1, #prefix) == prefix then
          local child = candidate:sub(#prefix + 1):match("^([^/]+)$")
          if child and child ~= "" then found[child] = true end
        end
      end
      for candidate in pairs(files) do
        if candidate:sub(1, #prefix) == prefix then
          local child = candidate:sub(#prefix + 1):match("^([^/]+)$")
          if child and child ~= "" then found[child] = true end
        end
      end
      local result = {}
      for child in pairs(found) do table.insert(result, child) end
      table.sort(result)
      return result
    end,
    copy = function(from, to)
      assert(files[from] ~= nil, "missing source " .. from)
      files[to] = files[from]
    end,
    move = function(from, to)
      assert(files[from] ~= nil, "missing move source " .. from)
      files[to], files[from] = files[from], nil
    end,
    delete = function(path) files[path] = nil end,
    getSize = function(path) return #(files[path] or "") end,
    open = function(path, mode)
      if mode == "r" then
        if files[path] == nil then return nil end
        return {
          readAll = function() return files[path] end,
          close = function() end,
        }
      end
      local buffer = ""
      return {
        write = function(value) buffer = buffer .. value end,
        close = function() files[path] = buffer end,
      }
    end,
  }
  _G.http = {
    get = function()
      downloads = downloads + 1
      local contents = "return {}" .. string.rep(" ", 277053)
      return {
        readAll = function() return contents end,
        close = function() end,
      }
    end,
  }
  _G.shell = {
    getRunningProgram = function()
      return "installer/install_terminal.lua"
    end,
    run = function(path, argument)
      setupRuns[#setupRuns + 1] = { path = path, argument = argument }
      return true
    end,
  }

  local ok, testError = pcall(function()
    local install = assert(loadfile("installer/install_terminal.lua"))
    install("slots")
    assert(downloads == 1)
    assert(#files["/casino/basalt.lua"] == 277062)
    assert(files["/casino/basalt.version"]
      == "2.5+a01ea6d577c92fcf76b5689f89eaf2920d011b82")
    assert(files["/casino/config.lua"] == "local-config")
    assert(files["/startup.lua"] == "slots-startup-v1")
    assert(files["/startup.before-mc-casino.lua"] == "existing-startup")
    assert(files["/casino/client/slots/main.lua"] == "slots-main-v1")
    assert(files["/casino/client/shared/components.lua"] == "shared-components")
    assert(files["/casino/shared/protocol.lua"] == "shared-protocol")
    assert(files["/casino/setup.lua"] == "setup-wizard")
    assert(files["/casino/role"] == "slots")

    files["src/client/slots/main.lua"] = "slots-main-v2"
    files["src/client/slots/startup.lua"] = "slots-startup-v2"
    install = assert(loadfile("installer/install_terminal.lua"))
    install("slots")
    assert(downloads == 1)
    assert(files["/casino/client/slots/main.lua"] == "slots-main-v2")
    assert(files["/startup.lua"] == "slots-startup-v2")
    assert(files["/startup.before-mc-casino.lua"] == "existing-startup")
    assert(files["/casino/config.lua"] == "local-config")

    files["/casino/config.lua"] = nil
    install = assert(loadfile("installer/install_terminal.lua"))
    install("slots")
    assert(#setupRuns == 1)
    assert(setupRuns[1].path == "/casino/setup.lua")
    assert(setupRuns[1].argument == "slots")
    assert(files["/casino/config.lua"] == "example-config")
  end)

  _G.fs = original.fs
  _G.http = original.http
  _G.shell = original.shell
  assert(ok, testError)
end

return tests
