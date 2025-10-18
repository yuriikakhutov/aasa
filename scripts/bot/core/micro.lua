---
-- Micro controller: translates tactical intent into specific orders.
---

local Log = require("scripts.bot.core.log")
local UZ = require("scripts.bot.vendors.uczone_adapter")

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
        orders.move = tactics.retreatPoint or UZ.safeRetreatPoint()
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
    end

    return orders
end

return Micro
