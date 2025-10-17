local logger = {}

local levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
local currentLevel = levels.INFO
local logHistory = {}
local maxEntries = 500
local lastLogTime = 0
local rateLimit = 0.1

local function level_value(level)
  return levels[level] or levels.INFO
end

function logger.configure(cfg)
  currentLevel = level_value(cfg.logLevel or "INFO")
  maxEntries = cfg.maxLogEntries or maxEntries
  rateLimit = cfg.logRateLimit or rateLimit
end

local function should_log(level)
  return level_value(level) <= currentLevel
end

local function push_entry(level, message)
  if #logHistory >= maxEntries then
    table.remove(logHistory, 1)
  end
  table.insert(logHistory, { level = level, message = message, time = os.clock() })
end

local function log(level, message)
  if not should_log(level) then
    return
  end
  local now = os.clock()
  if now - lastLogTime < rateLimit and level_value(level) >= levels.INFO then
    return
  end
  lastLogTime = now
  print(string.format("[BOT][%s] %s", level, message))
  push_entry(level, message)
end

function logger.info(msg)
  log("INFO", msg)
end

function logger.warn(msg)
  log("WARN", msg)
end

function logger.error(msg)
  log("ERROR", msg)
end

function logger.debug(msg)
  log("DEBUG", msg)
end

function logger.history()
  return logHistory
end

return logger
