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
        probpos = {},
        macro = {},
        path = {
            waypoints = {},
            lastPlanTime = -math.huge,
        },
        tactics = {},
        micro = {},
        orders = {},
        orderHistory = {},
        probables = {},
        antiStuck = { isStuck = false },
        validators = {
            rubick = {},
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

function Blackboard:appendOrderHistory(entries)
    for _, entry in ipairs(entries or {}) do
        table.insert(self.orderHistory, entry)
    end
end

return Blackboard
