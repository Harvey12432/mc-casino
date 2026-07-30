local JsonRepository = require("server.repositories.json_repository")
local util = require("shared.util")

local repository = {}

local function validJackpots(value)
  if type(value) ~= "table" then return false end
  if value.amounts == nil then
    for name, amount in pairs(value) do
      if type(name) ~= "string"
        or #name < 1
        or #name > 64
        or type(amount) ~= "number"
        or amount < 0
        or amount >= math.huge
        or amount ~= math.floor(amount)
      then
        return false
      end
    end
    return true
  end
  if type(value.amounts) ~= "table" or type(value.processed) ~= "table" then
    return false
  end
  for name, amount in pairs(value.amounts) do
    if type(name) ~= "string"
      or #name < 1
      or #name > 64
      or type(amount) ~= "number"
      or amount < 0
      or amount >= math.huge
      or amount ~= math.floor(amount)
    then
      return false
    end
  end
  for requestId, result in pairs(value.processed) do
    if type(requestId) ~= "string"
      or #requestId < 1
      or #requestId > 128
      or type(result) ~= "table"
      or result.requestId ~= requestId
      or type(result.name) ~= "string"
      or #result.name < 1
      or #result.name > 64
    then
      return false
    end
    for _, key in ipairs({ "before", "contribution", "claimed", "after" }) do
      local amount = result[key]
      if type(amount) ~= "number"
        or amount < 0
        or amount >= math.huge
        or amount ~= math.floor(amount)
      then
        return false
      end
    end
    local total = result.before + result.contribution
    if not ((result.claimed == 0 and result.after == total)
      or (result.claimed == total and result.after == 0))
    then
      return false
    end
  end
  return true
end

function repository.new(path)
  local store = JsonRepository.new(
    path or "/casino/data/jackpots.json",
    { amounts = { slots = 0 }, processed = {} },
    validJackpots
  )
  local instance = {}

  local function data()
    local value = store:get()
    if value.amounts == nil then
      store:update(function(candidate)
        local legacySlots = candidate.slots or 0
        for key in pairs(candidate) do candidate[key] = nil end
        candidate.amounts = { slots = legacySlots }
        candidate.processed = {}
      end)
      value = store:get()
    end
    return value
  end

  function instance:all()
    return util.copy(data().amounts)
  end

  function instance:get(name)
    return data().amounts[name] or 0
  end

  function instance:process(requestId, name, contribution, claim)
    local current = data()
    if current.processed[requestId] then
      return util.copy(current.processed[requestId])
    end
    local result
    store:update(function(value)
      local before = value.amounts[name] or 0
      local appliedContribution = math.max(0, math.floor(contribution or 0))
      local total = before + appliedContribution
      result = {
        requestId = requestId,
        name = name,
        before = before,
        contribution = appliedContribution,
        claimed = claim and total or 0,
        after = claim and 0 or total,
      }
      value.amounts[name] = result.after
      value.processed[requestId] = util.copy(result)
    end)
    return util.copy(result)
  end

  return instance
end

return repository
