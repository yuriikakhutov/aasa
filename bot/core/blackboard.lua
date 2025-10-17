local util = require("core.util")

local function vector_key(vec)
    if not vec then
        return "0:0"
    end
    return string.format("%d:%d", math.floor(vec.x or 0), math.floor(vec.y or 0))
end

local M = {
    config = {},
    hero = nil,
    heroData = {},
    mode = "roam",
    allies = {},
    enemies = {},
    creeps = {},
    neutrals = {},
    structures = {},
    events = {
        lastEnemySeen = {},
        lastDamage = {},
        lastMode = "roam",
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
    laneAssignment = nil,
    role = nil,
    nextRotationAt = 0,
    lastRuneTime = 0,
    pullTimers = {},
    stackTimers = {},
    buyQueue = {},
    skillPlan = {},
    itemPlan = {},
    dangerMap = {},
    farmHeatmap = {},
    enemyHints = {},
    lastOrderAt = 0,
    lastAttackAt = 0,
    lastMoveAt = 0,
    lastModeTime = 0,
    visibleEnemies = {},
    visibleCreeps = {},
    user_override_until = -math.huge,
    nextRuneTime = 0,
    nextStackTime = 0,
    farmEfficiency = 0,
    dangerLevel = 0,
    debugData = {},
}

function M:init(config)
    self.config = config or {}
    util.init(config)
end

function M:reset()
    self.hero = nil
    self.heroData = {}
    self.mode = "roam"
    self.allies = {}
    self.enemies = {}
    self.creeps = {}
    self.neutrals = {}
    self.structures = {}
    self.events.lastEnemySeen = {}
    self.events.lastDamage = {}
    self.events.lastMode = "roam"
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
    self.laneAssignment = nil
    self.role = nil
    self.nextRotationAt = 0
    self.lastRuneTime = 0
    self.pullTimers = {}
    self.stackTimers = {}
    self.buyQueue = {}
    self.skillPlan = {}
    self.itemPlan = {}
    self.dangerMap = {}
    self.farmHeatmap = {}
    self.enemyHints = {}
    self.lastOrderAt = 0
    self.lastAttackAt = 0
    self.lastMoveAt = 0
    self.lastModeTime = 0
    self.visibleEnemies = {}
    self.visibleCreeps = {}
    self.user_override_until = -math.huge
    self.nextRuneTime = 0
    self.nextStackTime = 0
    self.farmEfficiency = 0
    self.dangerLevel = 0
    self.debugData = {}
end

function M:updateHero(heroInfo)
    self.hero = heroInfo and heroInfo.entity or nil
    self.heroData = heroInfo or {}
    if heroInfo then
        self.hpRatio = heroInfo.health / math.max(heroInfo.maxHealth or 1, 1)
        self.manaRatio = heroInfo.mana / math.max(heroInfo.maxMana or 1, 1)
        self.combatRange = heroInfo.attackRange or self.combatRange
        self.healReady = heroInfo.canSelfHeal or false
        self.needGold = (heroInfo.networth or 0) < (heroInfo.nextItemCost or 0)
        self.debugData.hero = heroInfo
    end
end

local function check_allies(self)
    if not self.hero then
        return
    end
    local heroPos = Entity.GetAbsOrigin(self.hero)
    for _, ally in ipairs(self.allies) do
        if ally.entity ~= self.hero then
            local dist = util.distance2d(heroPos, ally.position)
            if dist < 1200 then
                self.allyNearby = true
                return
            end
        end
    end
    self.allyNearby = false
end

local function check_enemies(self)
    self.seenWeakEnemy = false
    local now = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
    for _, enemy in ipairs(self.enemies) do
        if enemy.isVisible and enemy.healthRatio < 0.4 then
            self.seenWeakEnemy = true
        end
        if enemy.lastSeenPos then
            local key = vector_key(enemy.lastSeenPos)
            local current = self.dangerMap[key] or 0
            local updated = util.lerp(current, 1.0, 0.5)
            self.dangerMap[key] = updated
            self.debugData.dangerMap = self.debugData.dangerMap or {}
            self.debugData.dangerMap[key] = updated
        end
        if enemy.lastSeenTime and now - enemy.lastSeenTime < 15 and enemy.position then
            local key = vector_key(enemy.position)
            self.dangerMap[key] = math.max(self.dangerMap[key] or 0, 0.9)
        end
    end
end

function M:updateUnits(allies, enemies, creeps, neutrals, structures)
    self.allies = allies or {}
    self.enemies = enemies or {}
    self.creeps = creeps or {}
    self.neutrals = neutrals or {}
    self.structures = structures or {}
    check_allies(self)
    check_enemies(self)
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
        self.dangerLevel = util.clamp(threatScore, 0, 1)
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
            if dist < (self.config.farmSearchRadius or 1800) then
                local danger = self:getDangerAt(creep.position)
                local score = (creep.bounty or 40) - danger * 100
                if score > bestScore then
                    best = creep.entity
                    bestScore = score
                end
            end
        end
    end
    return best
end

function M:canUse(abilityName)
    if not self.hero or not abilityName or not NPCs or not NPCs.GetAbilityByName then
        return false
    end
    local ability = NPCs.GetAbilityByName(self.hero, abilityName)
    if not ability then
        return false
    end
    if not Ability.IsReady or not Ability.IsReady(ability) then
        return false
    end
    return true
end

function M:canKill(enemy)
    if not enemy or not Entity.IsAlive(enemy) or not Entity.GetHealth then
        return false
    end
    local hp = Entity.GetHealth(enemy)
    local damage = (self.heroData.burstDamage or 0) + (self.heroData.attackDamage or 0) * 3
    return damage >= hp
end

function M:frontWavePos()
    if self.heroData and self.heroData.frontWave then
        return self.heroData.frontWave
    end
    return nil
end

function M:getDangerAt(pos)
    local key = vector_key(pos)
    return self.dangerMap[key] or 0
end

function M:updateDangerAt(pos, value)
    if not pos then
        return
    end
    local key = vector_key(pos)
    local decay = self.config.dangerDecay or 0.9
    local previous = self.dangerMap[key] or 0
    local nextValue = previous * decay + value * (1 - decay)
    self.dangerMap[key] = util.clamp(nextValue, 0, 1)
end

function M:decayDanger()
    local decay = self.config.dangerDecay or 0.9
    for key, value in pairs(self.dangerMap) do
        local nextValue = value * decay
        if nextValue < 0.05 then
            self.dangerMap[key] = nil
        else
            self.dangerMap[key] = nextValue
        end
    end
    self.dangerLevel = self.dangerLevel * decay
end

function M:updateFarmScore(id, pos, reward)
    if not id then
        return
    end
    local danger = self:getDangerAt(pos)
    local bias = self.config.farmSafetyBias or 0.35
    local score = (reward or 1) * (1 - bias) + (1 - danger) * bias
    local decay = self.config.farmHeatmapDecay or 0.85
    local prev = self.farmHeatmap[id] or score
    self.farmHeatmap[id] = prev * decay + score * (1 - decay)
    local total, count = 0, 0
    for _, value in pairs(self.farmHeatmap) do
        total = total + value
        count = count + 1
    end
    if count > 0 then
        self.farmEfficiency = total / count
    end
end

function M:bestFarmNode()
    local bestId, bestScore = nil, -math.huge
    for id, score in pairs(self.farmHeatmap) do
        if score > bestScore then
            bestId, bestScore = id, score
        end
    end
    return bestId, bestScore
end

function M:setLaneAssignment(lane, role)
    self.laneAssignment = lane
    if role then
        self.role = role
    end
end

function M:setRole(role)
    self.role = role
end

function M:scheduleRotation(time)
    self.nextRotationAt = time
end

function M:canRotate(now)
    return now >= (self.nextRotationAt or 0)
end

function M:recordRune(time)
    self.lastRuneTime = time
end

function M:setPullTimer(campId, time)
    self.pullTimers[campId] = time
end

function M:setStackTimer(campId, time)
    self.stackTimers[campId] = time
end

function M:enqueueBuy(item)
    if not item then
        return
    end
    table.insert(self.buyQueue, item)
end

function M:peekBuy()
    return self.buyQueue[1]
end

function M:dequeueBuy()
    if #self.buyQueue == 0 then
        return nil
    end
    return table.remove(self.buyQueue, 1)
end

function M:setPlans(items, skills)
    self.itemPlan = items or {}
    self.skillPlan = skills or {}
end

function M:markOrder(time)
    self.lastOrderAt = time
end

function M:markAttack(time)
    self.lastAttackAt = time
end

function M:markMove(time)
    self.lastMoveAt = time
end

function M:setMode(mode, time)
    if not mode then
        return
    end
    self.mode = mode
    self.events.lastMode = mode
    self.lastModeTime = time or self.lastModeTime
end

function M:setUserOverride(untilTime)
    if not untilTime then
        return
    end
    if untilTime > (self.user_override_until or -math.huge) then
        self.user_override_until = untilTime
    end
end

function M:isUserOverride(now)
    now = now or 0
    return now < (self.user_override_until or -math.huge)
end

function M:setNextRuneTime(time)
    if time and time > (self.nextRuneTime or 0) then
        self.nextRuneTime = time
    end
end

function M:setNextStackTime(time)
    if time and time > (self.nextStackTime or 0) then
        self.nextStackTime = time
    end
end

function M:getItem(name)
    if not self.heroData or not self.heroData.items then
        return nil
    end
    return self.heroData.items[name]
end

function M:isLowResources()
    return self.hpRatio < (self.config.healHpThreshold or 0.5) or self.manaRatio < (self.config.healManaThreshold or 0.4)
end

return M
