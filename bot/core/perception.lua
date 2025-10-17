local util = require("core.util")
local api = require("integration.uc_api")
local navLow = require("integration.nav")
local economy = require("core.economy")
local laning = require("core.laning")
local threat = require("core.threat")
local bb = require("core.blackboard")

local M = {}

local heal_items = {
    item_magic_stick = true,
    item_magic_wand = true,
    item_mekansm = true,
    item_guardian_greaves = true,
    item_spirit_vessel = true,
    item_holy_locket = true,
    item_eternal_shroud = true,
    item_soul_ring = true,
    item_bloodstone = true,
}

local function safe_call(func, ...)
    if not func then
        return nil
    end
    local ok, result = pcall(func, ...)
    if not ok then
        util.log("ERROR", "Perception call failed: " .. tostring(result))
        return nil
    end
    return result
end

local function collect_hero_info(hero)
    local pos = Entity.GetAbsOrigin(hero)
    local health = Entity.GetHealth(hero)
    local maxHealth = Entity.GetMaxHealth(hero)
    local mana = safe_call(NPC.GetMana, hero) or 0
    local maxMana = safe_call(NPC.GetMaxMana, hero) or 1
    local attackRange = (safe_call(NPC.GetAttackRange, hero) or 0) + (safe_call(NPC.GetAttackRangeBonus, hero) or 0)
    local damage = (safe_call(NPC.GetTrueDamage, hero) or (safe_call(NPC.GetMinDamage, hero) or 0)) + (safe_call(NPC.GetBonusDamage, hero) or 0)
    local moveSpeed = safe_call(NPC.GetMoveSpeed, hero) or 300
    local recentDamage = safe_call(Hero.GetRecentDamage, hero) or 0
    local heroData = {
        entity = hero,
        position = pos,
        health = health,
        maxHealth = maxHealth,
        mana = mana,
        maxMana = maxMana,
        attackRange = attackRange,
        attackDamage = damage,
        moveSpeed = moveSpeed,
        recentDamage = recentDamage,
        healthRatio = maxHealth > 0 and (health / maxHealth) or 0,
        manaRatio = maxMana > 0 and (mana / maxMana) or 0,
        networth = safe_call(NPC.GetNetWorth, hero) or 0,
        nextItemCost = 2000,
        safePressureThreshold = 0.55,
    }
    heroData.abilities = api.iterate_abilities(hero)
    heroData.items = api.iterate_items(hero)
    local canHeal = false
    for name, info in pairs(heroData.items) do
        if heal_items[name] and info and info.handle and Ability.IsReady(info.handle) then
            canHeal = true
            break
        end
    end
    heroData.canSelfHeal = canHeal
    heroData.comboDamage = threat.estimate_combo_damage(heroData)
    heroData.burstDamage = heroData.comboDamage
    return heroData
end

local function collect_unit_info(unit, heroTeam)
    local pos = Entity.GetAbsOrigin(unit)
    local health = Entity.GetHealth(unit)
    local maxHealth = Entity.GetMaxHealth(unit)
    local mana = safe_call(NPC.GetMana, unit) or 0
    local maxMana = safe_call(NPC.GetMaxMana, unit) or 1
    local attackRange = (safe_call(NPC.GetAttackRange, unit) or 0) + (safe_call(NPC.GetAttackRangeBonus, unit) or 0)
    local damage = safe_call(NPC.GetTrueDamage, unit) or (safe_call(NPC.GetMinDamage, unit) or 0)
    local info = {
        entity = unit,
        position = pos,
        health = health,
        maxHealth = maxHealth,
        mana = mana,
        maxMana = maxMana,
        attackRange = attackRange,
        attackDamage = damage,
        healthRatio = maxHealth > 0 and (health / maxHealth) or 0,
        manaRatio = maxMana > 0 and (mana / maxMana) or 0,
        isVisible = Entity.IsVisible and Entity.IsVisible(unit) or true,
        team = Entity.GetTeamNum(unit),
        lastSeenTime = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0,
    }
    info.isEnemy = heroTeam ~= info.team
    info.offensiveWeight = info.attackDamage / math.max(info.health, 1)
    info.boundingRadius = safe_call(NPC.GetHullRadius, unit) or 24
    if Entity.IsHero(unit) then
        info.abilities = api.iterate_abilities(unit)
        info.items = api.iterate_items(unit)
    end
    return info
end

local function collect_creeps(hero, team, radius)
    if not NPCs or not NPCs.InRadius then
        return {}
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local creeps = {}
    for _, creep in ipairs(NPCs.InRadius(heroPos, radius, team, Enum.TeamType.TEAM_ENEMY, true, true)) do
        table.insert(creeps, {
            entity = creep,
            position = Entity.GetAbsOrigin(creep),
            bounty = NPC.GetBountyXP and NPC.GetBountyXP(creep) or 45,
        })
    end
    for _, neutral in ipairs(NPCs.InRadius(heroPos, radius, Enum.TeamNum.TEAM_NEUTRAL, Enum.TeamType.TEAM_BOTH, true, true)) do
        table.insert(creeps, {
            entity = neutral,
            position = Entity.GetAbsOrigin(neutral),
            bounty = NPC.GetBountyXP and NPC.GetBountyXP(neutral) or 60,
        })
    end
    return creeps
end

local function evaluate_waves(hero, enemies, creeps)
    local team = Entity.GetTeamNum(hero.entity)
    local friendly = { size = 0, forwardDistance = 0 }
    local enemy = { size = 0, forwardDistance = 0 }
    local enemyFountain = navLow.get_fountain(team == Enum.TeamNum.TEAM_RADIANT and Enum.TeamNum.TEAM_DIRE or Enum.TeamNum.TEAM_RADIANT)
    local friendlyFountain = navLow.get_fountain(team)
    if enemyFountain and friendlyFountain then
        for _, creep in ipairs(creeps) do
            if creep.entity and NPC.IsLaneCreep and NPC.IsLaneCreep(creep.entity) then
                local creepPos = Entity.GetAbsOrigin(creep.entity)
                if Entity.IsSameTeam(creep.entity, hero.entity) then
                    friendly.size = friendly.size + 1
                    friendly.forwardDistance = friendly.forwardDistance + util.distance2d(creepPos, enemyFountain)
                else
                    enemy.size = enemy.size + 1
                    enemy.forwardDistance = enemy.forwardDistance + util.distance2d(creepPos, friendlyFountain)
                end
            end
        end
        if friendly.size > 0 then
            friendly.forwardDistance = friendly.forwardDistance / friendly.size
        end
        if enemy.size > 0 then
            enemy.forwardDistance = enemy.forwardDistance / enemy.size
        end
    end
    return friendly, enemy
end


local function collect_heroes(hero)
    local allies = {}
    local enemies = {}
    local heroTeam = Entity.GetTeamNum(hero)
    for _, unit in ipairs(Heroes.GetAll()) do
        if unit and Entity.IsAlive(unit) then
            if unit ~= hero then
                local info = collect_unit_info(unit, heroTeam)
                if Entity.IsSameTeam(unit, hero) then
                    table.insert(allies, info)
                else
                    table.insert(enemies, info)
                end
            end
        end
    end
    return allies, enemies
end

local function build_enemy_hints(enemies)
    local hints = {
        magicHeavy = false,
        silencers = false,
        illusions = false,
        healers = false,
        mobileCores = false,
        evasion = false,
    }
    for _, enemy in ipairs(enemies) do
        if enemy.abilities then
            for name, data in pairs(enemy.abilities) do
                if string.find(name, "silence") then
                    hints.silencers = true
                end
                if string.find(name, "illusion") then
                    hints.illusions = true
                end
                if string.find(name, "heal") then
                    hints.healers = true
                end
                if string.find(name, "blink") or string.find(name, "escape") then
                    hints.mobileCores = true
                end
                if data.damage and data.damage > 250 then
                    hints.magicHeavy = true
                end
            end
        end
        if enemy.items then
            for name in pairs(enemy.items) do
                if string.find(name, "butterfly") or string.find(name, "evasion") then
                    hints.evasion = true
                end
                if string.find(name, "radiance") then
                    hints.magicHeavy = true
                end
                if string.find(name, "manta") then
                    hints.illusions = true
                end
            end
        end
    end
    return hints
end

function M.scan(now, board)
    local state = board or bb
    state.visibleEnemies = {}
    state.visibleCreeps = {}

    local hero = api.self()
    if not hero then
        state.hero = nil
        state.heroData = {}
        state.hpRatio = 0
        state.manaRatio = 0
        return
    end

    if not Entity.IsAlive(hero) then
        if state.reset then
            state:reset()
        else
            state.hero = nil
            state.heroData = {}
            state.hpRatio = 0
            state.manaRatio = 0
        end
        return
    end

    if state.decayDanger then
        state:decayDanger()
    end

    local heroInfo = collect_hero_info(hero)
    state:updateHero(heroInfo)

    local allies, enemies = collect_heroes(hero)
    local creeps = collect_creeps(hero, Entity.GetTeamNum(hero), state.config.farmSearchRadius or 1600)
    local neutrals = {}
    local structures = {}
    state:updateUnits(allies, enemies, creeps, neutrals, structures)

    for _, enemy in ipairs(enemies) do
        if enemy.position then
            state:updateDangerAt(enemy.position, 1.0)
        end
        if enemy.isVisible ~= false then
            table.insert(state.visibleEnemies, enemy)
        end
    end

    for _, creep in ipairs(creeps) do
        if creep.entity then
            state:updateFarmScore("creep_" .. tostring(Entity.GetIndex(creep.entity)), creep.position, creep.bounty)
        end
        table.insert(state.visibleCreeps, creep)
    end

    local friendlyWave, enemyWave = evaluate_waves(heroInfo, enemies, creeps)
    state:updateCreepPressure(friendlyWave, enemyWave)

    local threatScore, winChance, safe = threat.evaluate(heroInfo, allies, enemies)
    state:updateThreat(threatScore, winChance, safe)

    local hints = build_enemy_hints(enemies)
    local changed = false
    for k, v in pairs(hints) do
        if not state.enemyHints or state.enemyHints[k] ~= v then
            changed = true
            break
        end
    end
    state.enemyHints = hints
    if changed then
        economy.planBuild(state.role or "carry", hints)
    end
    if not state.laneAssignment then
        laning.assign()
    end
    state.debugData.threat = {
        score = threatScore,
        win = winChance,
        safe = safe,
    }
end

return M
