---
-- DangerMap: keeps a decaying heat-map of dangerous positions such as
-- enemy tower ranges and last-seen enemy positions.
---

local UZ = require("scripts.bot.vendors.uczone_adapter")

local DangerMap = {}
DangerMap.__index = DangerMap

local DECAY_RATE = 0.92
local MIN_VALUE = 0.05

local function clonePos(pos)
    if not pos then
        return nil
    end
    return { x = pos.x, y = pos.y, z = pos.z }
end

function DangerMap.new()
    return setmetatable({
        hazards = {},
        lastTickTime = 0,
        threatLevel = 0,
    }, DangerMap)
end

local function addHazard(self, key, value, position)
    local entry = self.hazards[key] or { value = 0, position = clonePos(position) }
    entry.value = math.max(entry.value, value)
    entry.position = clonePos(position) or entry.position
    self.hazards[key] = entry
end

function DangerMap:ingest(sensors, memory)
    if not sensors or not sensors.valid then
        return
    end
    self.lastTickTime = sensors.time or self.lastTickTime

    local aggregate = 0

    for _, tower in ipairs(sensors.towers or {}) do
        local key = "tower: " .. (tower.team or "neutral") .. ":" .. tostring(tower.id or tower.name)
        addHazard(self, key, 1.0, tower.pos or tower.location)
        addHazard(self, key .. "-inner", 0.7, tower.pos or tower.location)
    end

    for id, data in pairs(memory and memory.enemies or {}) do
        if data.position then
            local danger = math.max(0.3, math.min(0.9, (data.unit and data.unit.level or 1) * 0.05))
            addHazard(self, "enemy:" .. tostring(id), danger, data.position)
            aggregate = aggregate + danger
        end
    end

    self.threatLevel = math.min(1, aggregate * 0.1)
end

function DangerMap:decay()
    for key, hazard in pairs(self.hazards) do
        hazard.value = hazard.value * DECAY_RATE
        if hazard.value < MIN_VALUE then
            self.hazards[key] = nil
        end
    end
end

local function distance(a, b)
    if not a or not b then
        return math.huge
    end
    return UZ.distance(a, b) or math.huge
end

function DangerMap:scorePosition(pos)
    local score = 0
    for _, hazard in pairs(self.hazards) do
        if hazard.position then
            local d = distance(pos, hazard.position)
            if d < 0.01 then
                d = 0.01
            end
            score = score + hazard.value / (d / 200 + 1)
        end
    end
    return score
end

return DangerMap
