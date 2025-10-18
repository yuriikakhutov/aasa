---
-- Micro controller: translates tactical intent into specific orders.
---

local Log = require("scripts.bot.core.logger")

local Micro = {}

local function heroRange(unit)
    return (unit and unit.attackRange) or 150
end

function Micro.execute(bb)
    local sensors = bb.sensors or {}
    if not sensors.valid then
        return {}
    end

    local tactics = bb.tactics or {}
    local orders = {}

    if tactics.mode == "disengage" then
        orders.move = tactics.retreatPoint or sensors.fountainPos
        orders.stopAttacking = true
        return orders
    end

    local focus = tactics.focus
    if focus and focus.pos then
        orders.attackTarget = focus
        orders.desiredRange = tactics.desiredRange or heroRange(sensors.self) - 10
    end

    local path = bb.path or {}
    if path.waypoints and #path.waypoints > 0 then
        orders.move = path.waypoints[math.min(2, #path.waypoints)]
    elseif focus and focus.pos then
        orders.move = focus.pos
    else
        orders.move = bb.macro and bb.macro.destination
    end

    if bb.antiStuck and bb.antiStuck.isStuck and sensors.pos then
        Log.warn("Anti-stuck triggered, forcing stop order")
        orders.stopAttacking = true
        orders.move = sensors.pos
    end

    return orders
end

return Micro
