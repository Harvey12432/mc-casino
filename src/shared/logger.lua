local logger = {}

local function write(level, message)
  print(("[%s] [%s] %s"):format(os.date("%H:%M:%S"), level, tostring(message)))
end

function logger.info(message)
  write("INFO", message)
end

function logger.warn(message)
  write("WARN", message)
end

function logger.error(message)
  write("ERROR", message)
end

return logger
