local installer = {}

function installer.ensureDirectory(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

function installer.copyTree(source, destination)
  assert(fs.exists(source), "Missing package path " .. source)
  installer.ensureDirectory(destination)
  for _, name in ipairs(fs.list(source)) do
    local from = fs.combine(source, name)
    local to = fs.combine(destination, name)
    if fs.isDir(from) then
      installer.copyTree(from, to)
    else
      if fs.exists(to) then fs.delete(to) end
      fs.copy(from, to)
    end
  end
end

function installer.copyFileIfMissing(source, destination)
  if not fs.exists(destination) then
    installer.ensureDirectory(fs.getDir(destination))
    fs.copy(source, destination)
  end
end

function installer.replaceFilePreserving(source, destination, backup)
  if fs.exists(destination) then
    if backup and not fs.exists(backup) then
      fs.copy(destination, backup)
    end
    fs.delete(destination)
  end
  fs.copy(source, destination)
end

return installer
