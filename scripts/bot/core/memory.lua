---
-- Memory: stores decaying information about the world such as last seen
-- enemy positions, rune timers and cast cooldown approximations.
---

local Memory = {}
Memory.__index = Memory

local ENEMY_TTL = 10.0
local RUNE_TTL = 120.0

local function unitId(unit)
    if type(unit) == "table" then
        return unit.id or unit.handle or unit.entindex or unit.name
    end
    return tostring(unit)
end

function Memory.new()
    return setmetatable({
        enemies = {},
        runes = {},
        enemyUltCooldowns = {},
        stolenAbilities = {},
        lastUpdate = 0,
    }, Memory)
end

function Memory:decay(now)
    for id, data in pairs(self.enemies) do
        if now - data.time > ENEMY_TTL then
            self.enemies[id] = nil
        end
    end
    for key, data in pairs(self.runes) do
        if now - data.time > RUNE_TTL then
            self.runes[key] = nil
        end
    end
end

function Memory:updateEnemies(now, enemyList)
    for _, enemy in ipairs(enemyList or {}) do
        local id = unitId(enemy)
        self.enemies[id] = {
            time = now,
            position = enemy.pos or enemy.location or enemy.origin,
            health = enemy.health,
            isVisible = true,
            unit = enemy,
        }
    end
end

function Memory:updateRunes(now, runes)
    for _, rune in ipairs(runes or {}) do
        local key = (rune.type or "") .. ":" .. (rune.spawnTime or 0)
        self.runes[key] = {
            time = now,
            data = rune,
        }
    end
end

function Memory:markEnemyCast(enemyName, abilityName, cooldown)
    local entry = self.enemyUltCooldowns[enemyName] or {}
    entry[abilityName] = {
        readyAt = self.lastUpdate + (cooldown or 0),
    }
    self.enemyUltCooldowns[enemyName] = entry
end

function Memory:updateFromSensors(sensors)
    if not sensors or not sensors.valid then
        return
    end
    self.lastUpdate = sensors.time or 0
    self:decay(self.lastUpdate)
    self:updateEnemies(self.lastUpdate, sensors.enemies)
    self:updateRunes(self.lastUpdate, sensors.runes)
end

return Memory
