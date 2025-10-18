---
-- Shared state container for the bot. All subsystems read/write via
-- accessor helpers to avoid tight coupling.
---

local Blackboard = {}
Blackboard.__index = Blackboard

function Blackboard.new()
    return setmetatable({
        sensors = {},
        memory = {},
        danger = {},
        macro = {},
        path = {
            waypoints = {},
            lastPlanTime = -math.huge,
        },
        tactics = {},
        micro = {},
        orders = {
            lastMove = { time = -math.huge, signature = nil },
            lastAttack = { time = -math.huge, signature = nil },
            lastCast = { time = -math.huge, signature = nil },
        },
        settings = {
            tickHigh = 0.15,
            tickCombat = 0.04,
            orderCooldown = 0.14,
        },
    }, Blackboard)
end

function Blackboard:update(section, data)
    self[section] = data
end

return Blackboard
