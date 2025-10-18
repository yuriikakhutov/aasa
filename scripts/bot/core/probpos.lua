---
-- Probabilistic position estimation for unseen enemies.
---

local ProbPos = {}
ProbPos.__index = ProbPos

local DEFAULT_SPEED = 320
local MAX_RADIUS = 2200

local function cloneVec(vec)
    if not vec then
        return nil
    end
    return { x = vec.x or 0, y = vec.y or 0, z = vec.z or 0 }
end

function ProbPos.new()
    return setmetatable({
        estimates = {},
    }, ProbPos)
end

local function estimateRadius(entry, now)
    local delta = math.max(0, now - (entry.time or now))
    local speed = entry.lastKnownSpeed or (entry.unit and entry.unit.movespeed) or DEFAULT_SPEED
    return math.min(MAX_RADIUS, speed * delta)
end

function ProbPos:update(memory, sensors)
    local now = (sensors and sensors.time) or os.clock()
    local estimates = {}
    for id, entry in pairs(memory.enemies or {}) do
        local position = entry.position or (entry.unit and entry.unit.pos)
        if position then
            local radius = estimateRadius(entry, now)
            estimates[id] = {
                lastSeen = entry.time,
                radius = radius,
                estimate = cloneVec(position),
                confidence = math.max(0.05, 1.0 - (now - entry.time) / 12.0),
            }
        end
    end
    self.estimates = estimates
    return estimates
end

return ProbPos

