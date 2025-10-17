local util = require("core.util")

local M = {
    config = {},
    hero = nil,
    heroData = {},
    allies = {},
    enemies = {},
    creeps = {},
    neutrals = {},
    structures = {},
    events = {
        lastEnemySeen = {},
        lastDamage = {},
        lastMode = "idle",
    },
    safe = true,
    threat = 0,
    winChance = 0.5,
    hpRatio = 1,
    manaRatio = 1,
    allyNearby = false,
    needGold = false,
    seenWeakEnemy = false,
    waveAdvantage = false,
    healReady = false,
    combatRange = 650,
    debugData = {},
}

function M:init(config)
    self.config = config or {}
    util.init(config)
end

function M:reset()
    self.hero = nil
    self.heroData = {}
    self.allies = {}
    self.enemies = {}
    self.creeps = {}
    self.neutrals = {}
    self.structures = {}
    self.events.lastEnemySeen = {}
    self.events.lastDamage = {}
    self.safe = true
    self.threat = 0
    self.winChance = 0.5
    self.hpRatio = 1
    self.manaRatio = 1
    self.allyNearby = false
    self.needGold = false
    self.seenWeakEnemy = false
    self.waveAdvantage = false
    self.healReady = false
    self.combatRange = 650
    self.debugData = {}
end

function M:updateHero(heroInfo)
    self.hero = heroInfo and heroInfo.entity or nil
    self.heroData = heroInfo or {}
    if heroInfo then
        self.hpRatio = heroInfo.health / math.max(heroInfo.maxHealth, 1)
        self.manaRatio = heroInfo.mana / math.max(heroInfo.maxMana, 1)
        self.combatRange = heroInfo.attackRange
        self.healReady = heroInfo.canSelfHeal or false
        self.needGold = (heroInfo.networth or 0) < (heroInfo.nextItemCost or 0)
        self.debugData.hero = heroInfo
    end
end

function M:updateUnits(allies, enemies, creeps, neutrals, structures)
    self.allies = allies or {}
    self.enemies = enemies or {}
    self.creeps = creeps or {}
    self.neutrals = neutrals or {}
    self.structures = structures or {}
    self.allyNearby = false
    self.seenWeakEnemy = false
    if self.hero then
        local heroPos = Entity.GetAbsOrigin(self.hero)
        for _, ally in ipairs(self.allies) do
            if ally.entity ~= self.hero then
                local dist = util.distance2d(heroPos, ally.position)
                if dist < 1200 then
                    self.allyNearby = true
                    break
                end
            end
        end
        for _, enemy in ipairs(self.enemies) do
            if enemy.isVisible and enemy.healthRatio < 0.4 then
                self.seenWeakEnemy = true
                break
            end
        end
    end
end

function M:updateCreepPressure(friendlyWave, enemyWave)
    if friendlyWave and enemyWave then
        self.waveAdvantage = friendlyWave.size > enemyWave.size and friendlyWave.forwardDistance > enemyWave.forwardDistance
    else
        self.waveAdvantage = false
    end
end

function M:updateThreat(threatScore, winChance, safe)
    if threatScore then
        self.threat = threatScore
    end
    if winChance then
        self.winChance = winChance
    end
    if safe ~= nil then
        self.safe = safe
    end
end

function M:updateEnemy(entityData)
    if not entityData or not entityData.entity then
        return
    end
    self.events.lastEnemySeen[Entity.GetIndex(entityData.entity)] = GameRules.GetGameTime()
end

function M:lastHit(amount, source)
    if not self.hero then
        return
    end
    local srcIndex = source and Entity.GetIndex(source) or 0
    self.events.lastDamage[srcIndex] = {
        time = GameRules.GetGameTime(),
        amount = amount,
    }
end

function M:isUnderThreat()
    return self.threat > 0.65 or self.hpRatio < (self.config.retreatHpThreshold or 0.3)
end

function M:bestTargetInRange(range)
    range = range or self.combatRange
    local hero = self.hero
    if not hero then
        return nil
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local best = nil
    local bestScore = -math.huge
    for _, enemy in ipairs(self.enemies) do
        if enemy.entity and Entity.IsAlive(enemy.entity) then
            local dist = util.distance2d(heroPos, enemy.position)
            if dist <= range + (enemy.boundingRadius or 0) then
                local hpFactor = 1.0 - enemy.healthRatio
                local threatFactor = enemy.offensiveWeight or 0.2
                local score = hpFactor * 0.7 + threatFactor * 0.3
                if enemy.isControlImmune then
                    score = score * 0.7
                end
                if score > bestScore then
                    best = enemy.entity
                    bestScore = score
                end
            end
        end
    end
    return best
end

function M:bestEnemy()
    local hero = self.hero
    if not hero then
        return nil
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local best = nil
    local bestScore = -math.huge
    for _, enemy in ipairs(self.enemies) do
        if enemy.entity and Entity.IsAlive(enemy.entity) then
            local dist = util.distance2d(heroPos, enemy.position)
            local distFactor = util.clamp(1 - (dist / 2500), 0, 1)
            local score = distFactor * 0.5 + (1 - enemy.healthRatio) * 0.5
            if enemy.isVisible then
                score = score + 0.1
            end
            if score > bestScore then
                best = enemy
                bestScore = score
            end
        end
    end
    return best
end

function M:safeFarmTarget()
    local hero = self.hero
    if not hero then
        return nil
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local best = nil
    local bestScore = -math.huge
    for _, creep in ipairs(self.creeps) do
        if creep.entity and Entity.IsAlive(creep.entity) then
            local dist = util.distance2d(heroPos, creep.position)
            if dist < (self.config.farmSearchRadius or 1500) then
                local hpFactor = 1 - (Entity.GetHealth(creep.entity) / math.max(Entity.GetMaxHealth(creep.entity), 1))
                local score = hpFactor - dist / 4000
                if score > bestScore then
                    best = creep.entity
                    bestScore = score
                end
            end
        end
    end
    return best
end

function M:canUse(name)
    if not self.heroData or not self.heroData.abilities then
        return false
    end
    local ability = self.heroData.abilities[name]
    if not ability and self.heroData.items then
        ability = self.heroData.items[name]
    end
    if not ability or not ability.handle then
        return false
    end
    if Ability.IsHidden and Ability.IsHidden(ability.handle) then
        return false
    end
    if not Ability.IsReady(ability.handle) then
        return false
    end
    if not Ability.IsOwnersManaEnough(ability.handle) then
        return false
    end
    return true
end

function M:getAbility(name)
    if not self.heroData or not self.heroData.abilities then
        return nil
    end
    local ability = self.heroData.abilities[name]
    return ability and ability.handle or nil
end

function M:getItem(name)
    if not self.heroData or not self.heroData.items then
        return nil
    end
    local item = self.heroData.items[name]
    return item and item.handle or nil
end

function M:canKill(targetEntity)
    if not targetEntity or not self.heroData or not self.heroData.comboDamage then
        return false
    end
    local hp = Entity.GetHealth(targetEntity)
    return self.heroData.comboDamage >= hp
end

function M:isLowResources()
    return self.hpRatio < (self.config.healHpThreshold or 0.45)
        or self.manaRatio < (self.config.healManaThreshold or 0.35)
end

return setmetatable(M, { __index = M })
