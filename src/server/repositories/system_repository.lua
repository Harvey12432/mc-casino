local JsonRepository = require("server.repositories.json_repository")
local util = require("shared.util")

local repository = {}

local function validState(value)
  if type(value) ~= "table"
    or type(value.maintenance) ~= "boolean"
    or type(value.disabledMachines) ~= "table"
  then
    return false
  end
  for computerId, disabled in pairs(value.disabledMachines) do
    local numericId = tonumber(computerId)
    if type(computerId) ~= "string"
      or not numericId
      or numericId < 0
      or numericId ~= math.floor(numericId)
      or tostring(numericId) ~= computerId
      or disabled ~= true
    then
      return false
    end
  end
  return true
end

function repository.new(path)
  local store = JsonRepository.new(
    path or "/casino/data/system.json",
    { maintenance = false, disabledMachines = {} },
    validState
  )
  local instance = {}

  function instance:get()
    return util.copy(store:get())
  end

  function instance:save(state)
    assert(type(state) == "table", "System state is required")
    local saved = util.copy(state)
    store:update(function(candidate)
      for key in pairs(candidate) do candidate[key] = nil end
      for key, value in pairs(saved) do candidate[key] = util.copy(value) end
    end)
  end

  return instance
end

return repository
