---
-- Pathing: requests navigation paths and filters against danger map.
---

local Log = require("scripts.bot.core.log")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Pathing = {}

local REPLAN_INTERVAL = 0.4

local function safeCall(name, ...)
    local fn = UZ[name]
    if not fn then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    Log.error("Pathing adapter failure: " .. tostring(name) .. " -> " .. tostring(result))
    return nil
end

local function filterByDanger(points, dangerMap)
    if not points or not dangerMap then
        return points
    end
    local filtered = {}
    for _, point in ipairs(points) do
        local score = dangerMap:scorePosition(point)
        if score < 1.2 then
            table.insert(filtered, point)
        end
    end
    if #filtered == 0 then
        return points
    end
    return filtered
end

function Pathing.plan(bb)
    local now = bb.sensors and bb.sensors.time or os.clock()
    local pathState = bb.path or {}
    if pathState.lastPlanTime and now - pathState.lastPlanTime < REPLAN_INTERVAL then
        return pathState
    end

    local objective = bb.macro
    local sensors = bb.sensors
    if not objective or not sensors then
        return pathState
    end

    local targetPos = objective.params and objective.params.position
    if not targetPos then
        return pathState
    end

    local path = safeCall("navMeshPath", sensors.pos, targetPos)
    if not path or #path == 0 then
        path = { sensors.pos, targetPos }
    end

    path = filterByDanger(path, bb.danger)

    pathState = {
        waypoints = path,
        lastPlanTime = now,
        objective = objective,
    }
    bb.path = pathState
    return pathState
end

return Pathing
