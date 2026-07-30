local network = {}

function network.open(modemSide)
  if modemSide then
    rednet.open(modemSide)
    return
  end

  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      rednet.open(name)
      return
    end
  end

  error("No modem was found")
end

function network.send(recipientId, message, protocolName)
  return rednet.send(recipientId, message, protocolName)
end

function network.receive(protocolName, timeout)
  return rednet.receive(protocolName, timeout)
end

function network.lookup(protocolName, hostname)
  return rednet.lookup(protocolName, hostname)
end

return network
