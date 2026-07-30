local validation = {}

function validation.isNonEmptyString(value, maximumLength)
  return type(value) == "string"
    and #value > 0
    and #value <= (maximumLength or 128)
end

function validation.isCreditAmount(value)
  return type(value) == "number"
    and value == math.floor(value)
    and value > 0
    and value < math.huge
end

function validation.isPlayerName(value)
  return type(value) == "string"
    and #value >= 1
    and #value <= 32
    and value:match("^[A-Za-z0-9_]+$") ~= nil
end

local function boundedValue(value, depth, budget, seen)
  local valueType = type(value)
  if valueType == "string" then return #value <= budget.maxStringLength end
  if valueType == "number" then
    return value == value and value < math.huge and value > -math.huge
  end
  if valueType == "boolean" or valueType == "nil" then
    return true
  end
  if valueType ~= "table" or depth > budget.maxDepth or seen[value] then
    return false
  end
  seen[value] = true
  for key, child in pairs(value) do
    budget.count = budget.count + 1
    if budget.count > budget.maxEntries
      or not boundedValue(key, depth + 1, budget, seen)
      or not boundedValue(child, depth + 1, budget, seen)
    then
      return false
    end
  end
  seen[value] = nil
  return true
end

function validation.isBoundedPayload(
  value,
  maximumEntries,
  maximumDepth,
  maximumStringLength
)
  return boundedValue(value, 1, {
    count = 0,
    maxEntries = maximumEntries or 128,
    maxDepth = maximumDepth or 4,
    maxStringLength = maximumStringLength or 256,
  }, {})
end

function validation.isRequest(message)
  return type(message) == "table"
    and validation.isNonEmptyString(message.type, 64)
    and validation.isNonEmptyString(message.requestId, 128)
    and validation.isNonEmptyString(message.casinoId, 64)
    and (message.sessionToken == nil
      or validation.isNonEmptyString(message.sessionToken, 128))
    and type(message.payload) == "table"
    and validation.isBoundedPayload(message.payload)
end

return validation
