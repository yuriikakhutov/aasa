---@class Log
local Log = {}

local debugEnabled = false
local lastPrint = 0

---Enables or disables debug logging at runtime.
---@param enabled boolean
function Log.setDebug(enabled)
	debugEnabled = not not enabled
end

---Returns true when debug logs are currently enabled.
---@return boolean
function Log.isDebug()
	return debugEnabled
end

---Internal print helper that throttles messages to avoid spamming.
---@param level string
---@param msg string
local function emit(level, msg)
	local now = os.clock()
	if now - lastPrint < 0.02 then
		return
	end
	lastPrint = now
	print(string.format("[UCZoneBot][%s] %s", level, msg))
end

---Logs an informational message.
---@param msg string
function Log.info(msg)
	emit("INFO", msg)
end

---Logs a warning message.
---@param msg string
function Log.warn(msg)
	emit("WARN", msg)
end

---Logs an error message.
---@param msg string
function Log.error(msg)
	emit("ERROR", msg)
end

---Logs a debug message if debug is enabled.
---@param msg string
function Log.debug(msg)
	if not debugEnabled then
		return
	end
	emit("DEBUG", msg)
end

return Log
