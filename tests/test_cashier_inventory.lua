local tests = {}

local function makeInventory(name, slots, all)
  local inventory = {}
  function inventory.list()
    local result = {}
    for slot, item in pairs(slots) do
      if item.count > 0 then
        result[slot] = { name = item.name, count = item.count }
      end
    end
    return result
  end
  function inventory.pushItems(destinationName, slot, limit)
    local item = slots[slot]
    if not item or item.count <= 0 then return 0 end
    local moved = math.min(item.count, limit or item.count)
    item.count = item.count - moved
    local destination = all[destinationName]
    local targetSlot = 1
    while destination.slots[targetSlot]
      and destination.slots[targetSlot].name ~= item.name
    do
      targetSlot = targetSlot + 1
    end
    if not destination.slots[targetSlot] then
      destination.slots[targetSlot] = { name = item.name, count = 0 }
    end
    destination.slots[targetSlot].count =
      destination.slots[targetSlot].count + moved
    return moved
  end
  return { name = name, slots = slots, api = inventory }
end

function tests.cashier_moves_only_configured_currency()
  local originalPeripheral = _G.peripheral
  local previousConfig = package.loaded["shared.config"]
  local previousInventory = package.loaded["client.cashier.inventory"]

  local inventories = {}
  inventories.input = makeInventory("input", {
    [1] = { name = "minecraft:emerald", count = 10 },
    [2] = { name = "minecraft:diamond", count = 5 },
  }, inventories)
  inventories.vault = makeInventory("vault", {}, inventories)
  inventories.output = makeInventory("output", {}, inventories)

  package.loaded["shared.config"] = {
    cashierInput = "input",
    cashierVault = "vault",
    cashierOutput = "output",
    currencyItem = "minecraft:emerald",
  }
  package.loaded["client.cashier.inventory"] = nil
  _G.peripheral = {
    wrap = function(name)
      return inventories[name] and inventories[name].api or nil
    end,
  }

  local Inventory = require("client.cashier.inventory")
  local ok, testError = pcall(function()
    local cashier = Inventory.new()
    assert(cashier:availableForDeposit() == 10)
    assert(cashier:deposit(7) == 7)
    assert(cashier:availableForDeposit() == 3)
    assert(cashier:availableForWithdrawal() == 7)
    assert(cashier:withdraw(4) == 4)
    assert(cashier:availableForWithdrawal() == 3)
    assert(inventories.input.slots[2].count == 5)
    assert(inventories.output.slots[1].name == "minecraft:emerald")
    assert(inventories.output.slots[1].count == 4)
  end)

  _G.peripheral = originalPeripheral
  package.loaded["shared.config"] = previousConfig
  package.loaded["client.cashier.inventory"] = previousInventory
  assert(ok, testError)
end

return tests
