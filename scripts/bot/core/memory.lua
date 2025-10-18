local Log = require("scripts.bot.core.log")

---@class MemoryModule
local Memory = {}
Memory.__index = Memory

local ENEMY_DECAY = 9.0

---@return MemoryModule
function Memory.new()
    local self = setmetatable({}, Memory)
    self.enemies = {}
    self.runeTimers = {}
    self.cooldowns = {}
    return self
end

---@param snapshot table
function Memory:update(snapshot)
    local now = snapshot and snapshot.time or os.clock()
    if snapshot and snapshot.enemies then
        for _, enemy in ipairs(snapshot.enemies) do
            local id = enemy.id or enemy.handle
            if id then
                self.enemies[id] = {
                    lastSeen = now,
                    pos = enemy.pos or enemy.location or enemy
                }
            end
        end
    end

    for id, data in pairs(self.enemies) do
        if now - data.lastSeen > ENEMY_DECAY then
            self.enemies[id] = nil
        end
    end
end

---@param enemyId any
---@return table|nil
function Memory:enemyPosition(enemyId)
    local data = self.enemies[enemyId]
    if not data then
        return nil
    end
    return data.pos
end

---@param abilityName string
---@param readyAt number
function Memory:setCooldown(abilityName, readyAt)
    self.cooldowns[abilityName] = readyAt
end

---@param abilityName string
---@return number|nil
function Memory:getCooldown(abilityName)
    return self.cooldowns[abilityName]
end

return Memory
