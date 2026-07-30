local util = {}
local idSequence = 0

function util.copy(value)
  if type(value) ~= "table" then
    return value
  end

  local result = {}
  for key, child in pairs(value) do
    result[util.copy(key)] = util.copy(child)
  end
  return result
end

function util.newId(prefix)
  idSequence = idSequence + 1
  return ("%s:%d:%d:%d"):format(
    prefix,
    os.getComputerID(),
    math.floor(os.epoch("utc")),
    idSequence
  )
end

function util.clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

return util
