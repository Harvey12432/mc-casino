local args = { ... }
local role = args[1]

if role == "server" then
  shell.run(fs.combine(fs.getDir(shell.getRunningProgram()), "install_server.lua"))
  return
end

if role then
  shell.run(
    fs.combine(fs.getDir(shell.getRunningProgram()), "install_terminal.lua"),
    role
  )
  return
end

error("Usage: update <server|terminal-role>")
