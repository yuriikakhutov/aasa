local util = require("core.util")

local M = {}

local function hero_power(unit)
    local hpRatio = unit.health / math.max(unit.maxHealth, 1)
    local manaRatio = unit.mana / math.max(unit.maxMana, 1)
    local damageRecent = unit.recentDamage or 0
    local attackRange = unit.attackRange or 600
    local dps = unit.dps or (damageRecent * 0.5)
    return hpRatio * 0.6 + manaRatio * 0.2 + (dps / 400)
end

local function enemy_pressure(hero, enemy)
    local dist = util.distance2d(hero.position, enemy.position)
    local threatRange = math.max(hero.attackRange or 600, enemy.attackRange or 600) + 200
    local distanceFactor = util.clamp(1 - (dist / threatRange), 0, 1)
    local healthFactor = 1 - enemy.healthRatio
    local damageFactor = (enemy.recentDamage or 0) / math.max(hero.maxHealth, 1)
    local controlFactor = enemy.hasDisable and 0.2 or 0
    return distanceFactor * (0.6 + damageFactor) + controlFactor + healthFactor * 0.2
end

function M.evaluate(hero, allies, enemies)
    if not hero then
        return 0.0, 0.5, true
    end
    local heroMetrics = {
        position = hero.position,
        attackRange = hero.attackRange,
        maxHealth = hero.maxHealth,
    }
    local allyPower = hero_power(hero)
    for _, ally in ipairs(allies or {}) do
        allyPower = allyPower + hero_power(ally)
    end
    local enemyPower = 0
    local maxPressure = 0
    for _, enemy in ipairs(enemies or {}) do
        local pressure = enemy_pressure(heroMetrics, enemy)
        maxPressure = math.max(maxPressure, pressure)
        enemyPower = enemyPower + hero_power(enemy)
    end
    local winChance = 0.5
    if allyPower + enemyPower > 0 then
        winChance = util.clamp(allyPower / (allyPower + enemyPower), 0.05, 0.95)
    end
    local safe = maxPressure < (hero.safePressureThreshold or 0.55)
    return util.clamp(maxPressure, 0, 1.5), winChance, safe
end

local function ability_damage(ability)
    if not ability or not ability.handle then
        return 0
    end
    if not Ability.IsReady(ability.handle) then
        return 0
    end
    local baseDamage = Ability.GetDamage and Ability.GetDamage(ability.handle) or 0
    if baseDamage <= 0 and Ability.GetLevel then
        local lvl = Ability.GetLevel(ability.handle)
        if Ability.GetLevelSpecialValueFor then
            baseDamage = Ability.GetLevelSpecialValueFor(ability.handle, "damage", lvl - 1)
        end
    end
    return baseDamage or 0
end

function M.estimate_combo_damage(heroData)
    if not heroData or not heroData.abilities then
        return 0
    end
    local total = heroData.attackDamage or 0
    for name, ability in pairs(heroData.abilities) do
        total = total + ability_damage(ability)
    end
    if heroData.items then
        for name, item in pairs(heroData.items) do
            total = total + ability_damage(item)
        end
    end
    return total
end

function M.kill_probability(heroData, target)
    if not heroData or not target then
        return 0
    end
    local hp = target.health
    local combo = heroData.comboDamage or 0
    if hp <= 0 then
        return 1
    end
    return util.clamp(combo / hp, 0, 1)
end

return M
