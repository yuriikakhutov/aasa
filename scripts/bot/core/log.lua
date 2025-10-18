---
-- Lightweight logging helpers with dynamic verbosity control.
-- All modules should use this logger instead of printing directly.
-- The logger survives missing UCZone APIs by wrapping output in pcall.
---

local Log = {}

local debugEnabled = false
local lastSinkFailure = 0

---Sets the logger verbosity.
---@param enabled boolean
function Log.setDebug(enabled)
	debugEnabled = enabled and true or false
end

---Internal sink for log messages.
---@param level string
---@param msg string
local function sink(level, msg)
	local ok = pcall(function()
		print(string.format("[UCZoneBot][%s] %s", level, msg))
	end)
	if not ok then
		lastSinkFailure = os.clock()
		-- swallow errors; logging must never break the bot
	end
end

---Writes an informational log message.
---@param msg string
function Log.info(msg)
	sink("INFO", msg)
end

---Writes a debug log message if debug mode is enabled.
---@param msg string
function Log.debug(msg)
	if debugEnabled then
		sink("DEBUG", msg)
	end
end

---Writes a warning log message.
---@param msg string
function Log.warn(msg)
	sink("WARN", msg)
end

---Writes an error log message.
---@param msg string
function Log.error(msg)
	sink("ERROR", msg)
end

return Log
