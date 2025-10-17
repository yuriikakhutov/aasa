local actions = require("core.actions")
local util = require("core.util")

local M = {
    lastCommand = {
        key = nil,
        time = -math.huge,
    },
    cooldown = 0.12,
}

local function throttled(key, time)
    if M.lastCommand.key == key and (time - M.lastCommand.time) < M.cooldown then
        return true
    end
    M.lastCommand.key = key
    M.lastCommand.time = time
    return false
end

function M.run(mode, time)
    time = time or 0
    if not mode then
        return
    end
    if throttled(mode, time) then
        return
    end
    util.safe_call(actions.execute, mode)
end

return M
