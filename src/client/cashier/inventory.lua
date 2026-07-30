local config = require("shared.config")

local inventory = {}
inventory.__index = inventory

local function wrap(name, label)
  assert(type(name) == "string" and name ~= "", label .. " is not configured")
  local wrapped = peripheral.wrap(name)
  assert(wrapped and type(wrapped.list) == "function", label .. " is not an inventory")
  return wrapped
end

local function countItem(source, itemName)
  local count = 0
  for _, item in pairs(source.list()) do
    if item.name == itemName then count = count + item.count end
  end
  return count
end

local function transfer(source, destinationName, itemName, amount)
  local moved = 0
  for slot, item in pairs(source.list()) do
    if item.name == itemName and moved < amount then
      moved = moved + source.pushItems(
        destinationName,
        slot,
        math.min(item.count, amount - moved)
      )
    end
  end
  return moved
end

function inventory.new()
  return setmetatable({
    input = wrap(config.cashierInput, "cashierInput"),
    inputName = config.cashierInput,
    vault = wrap(config.cashierVault, "cashierVault"),
    vaultName = config.cashierVault,
    output = wrap(config.cashierOutput, "cashierOutput"),
    outputName = config.cashierOutput,
    itemName = config.currencyItem,
  }, inventory)
end

function inventory:availableForDeposit()
  return countItem(self.input, self.itemName)
end

function inventory:availableForWithdrawal()
  return countItem(self.vault, self.itemName)
end

function inventory:deposit(amount)
  return transfer(self.input, self.vaultName, self.itemName, amount)
end

function inventory:rollbackDeposit(amount)
  return transfer(self.vault, self.inputName, self.itemName, amount)
end

function inventory:withdraw(amount)
  return transfer(self.vault, self.outputName, self.itemName, amount)
end

return inventory
