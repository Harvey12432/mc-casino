local util = require("shared.util")

local repository = {}
repository.__index = repository

local function parentDirectory(path)
  return fs.getDir(path)
end

local function readJson(path)
  if not fs.exists(path) then
    return nil, "File does not exist"
  end

  local handle = fs.open(path, "r")
  if not handle then
    return nil, "Unable to open " .. path
  end

  local contents = handle.readAll()
  handle.close()
  local value = textutils.unserializeJSON(contents)
  if value == nil then
    return nil, "Invalid JSON in " .. path
  end
  return value
end

function repository.new(path, defaultValue, validator)
  return setmetatable({
    path = path,
    backupPath = path .. ".bak",
    temporaryPath = path .. ".tmp",
    defaultValue = util.copy(defaultValue),
    validator = validator,
    value = nil,
  }, repository)
end

function repository:validate(value)
  if self.validator and not self.validator(value) then
    return false, "Data validation failed for " .. self.path
  end
  return true
end

function repository:load()
  if not fs.exists(self.path) then
    if fs.exists(self.backupPath) then
      local backup, backupError = readJson(self.backupPath)
      if not backup then
        error(("Cannot recover %s: %s"):format(self.path, backupError))
      end
      local valid, validationError = self:validate(backup)
      if not valid then
        error(("Cannot recover %s: %s"):format(self.path, validationError))
      end
      self.value = backup
      fs.copy(self.backupPath, self.path)
      return backup
    end
    self.value = util.copy(self.defaultValue)
    self:save()
    return self.value
  end

  local value, loadError = readJson(self.path)
  if value then
    local valid, validationError = self:validate(value)
    if valid then
      self.value = value
      return value
    end
    loadError = validationError
  end

  local backup = readJson(self.backupPath)
  if backup then
    local valid = self:validate(backup)
    if valid then
      self.value = backup
      if fs.exists(self.path) then fs.delete(self.path) end
      fs.copy(self.backupPath, self.path)
      return backup
    end
  end

  error(("Cannot recover %s: %s"):format(self.path, loadError or "unknown error"))
end

function repository:get()
  if self.value == nil then
    return self:load()
  end
  return self.value
end

function repository:save()
  assert(self.value ~= nil, "Repository must be loaded before saving")
  local valid, validationError = self:validate(self.value)
  assert(valid, validationError)

  local directory = parentDirectory(self.path)
  if directory ~= "" and not fs.exists(directory) then
    fs.makeDir(directory)
  end

  local encoded = textutils.serializeJSON(self.value)
  local temporary = fs.open(self.temporaryPath, "w")
  assert(temporary, "Unable to open temporary file " .. self.temporaryPath)
  temporary.write(encoded)
  temporary.close()

  local check, checkError = readJson(self.temporaryPath)
  assert(check, checkError)
  local checkValid, checkValidationError = self:validate(check)
  assert(checkValid, checkValidationError)

  if fs.exists(self.backupPath) then
    fs.delete(self.backupPath)
  end
  if fs.exists(self.path) then
    fs.move(self.path, self.backupPath)
  end
  fs.move(self.temporaryPath, self.path)
end

function repository:update(mutator)
  assert(type(mutator) == "function", "Repository update requires a function")
  local original = self:get()
  local candidate = util.copy(original)
  local result = mutator(candidate)
  self.value = candidate
  local saved, saveError = pcall(self.save, self)
  if not saved then
    self.value = original
    error(saveError, 0)
  end
  return result
end

return repository
