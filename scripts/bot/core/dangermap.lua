local UZ = require("scripts.bot.vendors.uczone_adapter")

---@class DangerMap
local DangerMap = {}
DangerMap.__index = DangerMap

local DECAY = 0.92
local MAX_RADIUS = 2800

---@return DangerMap
function DangerMap.new()
    local self = setmetatable({}, DangerMap)
    self.grid = {}
    self.lastTick = 0
    return self
end

---@param snapshot table
function DangerMap:update(snapshot)
    local now = snapshot and snapshot.time or os.clock()
    if now - self.lastTick > 0.2 then
        for key, value in pairs(self.grid) do
            self.grid[key] = value * DECAY
            if self.grid[key] < 0.01 then
                self.grid[key] = nil
            end
        end
        self.lastTick = now
    end

    if not snapshot then
        return
    end

    local function addDanger(pos, amount, radius)
        local key = string.format("%d:%d", math.floor(pos.x or 0), math.floor(pos.y or 0))
        self.grid[key] = math.max(self.grid[key] or 0, amount)
    end

    for _, enemy in ipairs(snapshot.enemies or {}) do
        if enemy.pos then
            addDanger(enemy.pos, 1.0, 800)
        end
    end

    for _, tower in ipairs(UZ.towers(snapshot.selfUnit and snapshot.selfUnit.team or UZ.team())) do
        if tower.team ~= (snapshot.selfUnit and snapshot.selfUnit.team) then
            addDanger(tower.pos or tower.location or {}, 1.5, 900)
        end
    end
end

---@param pos table
---@return number
function DangerMap:at(pos)
    local key = string.format("%d:%d", math.floor(pos.x or 0), math.floor(pos.y or 0))
    return self.grid[key] or 0
end

return DangerMap
