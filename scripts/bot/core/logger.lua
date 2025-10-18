---
-- Structured logger with leveled output and throttle logic to protect the bot
-- from spamming stdout or crashing when the print sink is unavailable.
---

local Logger = {}

local LEVEL_ORDER = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local currentLevel = LEVEL_ORDER.INFO
local debugEnabled = false
local lastEmit = {
    ERROR = -math.huge,
    WARN = -math.huge,
}

local sink

---Allows dependency injection of a print sink (useful for tests).
---@param fn fun(msg:string)|nil
function Logger.setSink(fn)
    sink = fn
end

---Sets the minimum log level that will be emitted.
---@param level string
function Logger.setLevel(level)
    if LEVEL_ORDER[level] then
        currentLevel = LEVEL_ORDER[level]
    end
end

---Enables or disables verbose debug output while keeping INFO default level.
---@param enabled boolean
function Logger.setDebug(enabled)
    debugEnabled = enabled and true or false
end

local function shouldEmit(levelName)
    local order = LEVEL_ORDER[levelName] or LEVEL_ORDER.INFO
    if order >= currentLevel then
        return true
    end
    if levelName == "DEBUG" or levelName == "TRACE" then
        return debugEnabled
    end
    return false
end

local function defaultSink(msg)
    print(msg)
end

local function emit(levelName, fmt, ...)
    if not shouldEmit(levelName) then
        return
    end
    local now = os.clock()
    if (levelName == "ERROR" or levelName == "WARN") and now - (lastEmit[levelName] or -math.huge) < 0.05 then
        return
    end
    lastEmit[levelName] = now
    local message
    if select("#", ...) > 0 then
        message = string.format(fmt, ...)
    else
        message = tostring(fmt)
    end
    local line = string.format("[UCZoneBot][%s] %s", levelName, message)
    local target = sink or defaultSink
    local ok = pcall(target, line)
    if not ok then
        -- If we fail to emit the log we simply swallow the error to guarantee
        -- the bot keeps running.
        sink = defaultSink
        pcall(sink, line)
    end
end

function Logger.trace(fmt, ...)
    emit("TRACE", fmt, ...)
end

function Logger.debug(fmt, ...)
    emit("DEBUG", fmt, ...)
end

function Logger.info(fmt, ...)
    emit("INFO", fmt, ...)
end

function Logger.warn(fmt, ...)
    emit("WARN", fmt, ...)
end

function Logger.error(fmt, ...)
    emit("ERROR", fmt, ...)
end

return Logger

