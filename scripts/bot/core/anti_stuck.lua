---
-- Detects stuck behaviour by monitoring positional deltas over time.
---

local AntiStuck = {}
AntiStuck.__index = AntiStuck

local WINDOW = 2.5
local MIN_TRAVEL = 60

local function distance(a, b)
    if not a or not b then
        return 0
    end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function AntiStuck.new()
    return setmetatable({ samples = {} }, AntiStuck)
end

function AntiStuck:record(time, pos)
    if not pos then
        return
    end
    table.insert(self.samples, { time = time, pos = { x = pos.x or 0, y = pos.y or 0, z = pos.z or 0 } })
    local cutoff = time - WINDOW
    local i = 1
    while i <= #self.samples do
        if self.samples[i].time < cutoff then
            table.remove(self.samples, i)
        else
            break
        end
    end
end

function AntiStuck:isStuck()
    if #self.samples < 2 then
        return false
    end
    local oldest = self.samples[1]
    local newest = self.samples[#self.samples]
    return distance(oldest.pos, newest.pos) < MIN_TRAVEL
end

return AntiStuck

