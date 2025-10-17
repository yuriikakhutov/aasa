local events = require("core.events")
local util = require("core.util")
local api = require("integration.uc_api")

local M = {
    lastTime = 0,
}

local function dispatch_tick()
    local time = api.time()
    local dt = time - (M.lastTime or time)
    M.lastTime = time
    util.tick_reset(time)
    events.dispatch({ type = "tick", time = time, dt = dt })
end

function M.build()
    return {
        OnUpdate = function()
            dispatch_tick()
        end,
        OnEntityCreate = function(entity)
            events.dispatch({ type = "entity_create", entity = entity })
        end,
        OnEntityDestroy = function(entity)
            events.dispatch({ type = "entity_destroy", entity = entity })
        end,
        OnEntityHurt = function(data)
            events.dispatch({ type = "damage", data = data })
        end,
        OnEntityKilled = function(data)
            events.dispatch({ type = "entity_killed", data = data })
        end,
    }
end

return M
