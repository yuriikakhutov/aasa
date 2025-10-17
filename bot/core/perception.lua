local util = require("core.util")
local api = require("integration.uc_api")
local nav = require("integration.nav")
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
    local heroPlayerId = safe_call(Hero.GetPlayerID, hero)
    local player = api.player()
    if heroPlayerId and Players and Players.GetPlayer then
        player = Players.GetPlayer(heroPlayerId) or player
    end
    local networth = nil
    if player and Player.GetTeamPlayer then
        local data = safe_call(Player.GetTeamPlayer, player)
        networth = data and data.networth or nil
    end
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
        networth = networth or 0,
        nextItemCost = 2000,
        safePressureThreshold = 0.55,
    }
    heroData.abilities = api.iterate_abilities(hero)
    heroData.items = api.iterate_items(hero)
    local canHeal = false
    for name, info in pairs(heroData.items) do
        if heal_items[name] and Ability.IsReady(info.handle) then
            canHeal = true
            break
        end
    end
    heroData.canSelfHeal = canHeal
    heroData.comboDamage = threat.estimate_combo_damage(heroData)
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
    local enemyRecent = nil
    if Entity.IsHero(unit) then
        enemyRecent = safe_call(Hero.GetRecentDamage, unit)
    end
    local info = {
        entity = unit,
        position = pos,
        health = health,
        maxHealth = maxHealth,
        mana = mana,
        maxMana = maxMana,
        attackRange = attackRange,
        attackDamage = damage,
        recentDamage = enemyRecent or 0,
        healthRatio = maxHealth > 0 and (health / maxHealth) or 0,
        manaRatio = maxMana > 0 and (mana / maxMana) or 0,
        isVisible = Entity.IsVisible and Entity.IsVisible(unit) or true,
        team = Entity.GetTeamNum(unit),
    }
    info.isEnemy = not Entity.IsSameTeam(unit, api.self())
    info.offensiveWeight = info.attackDamage / math.max(info.health, 1)
    if NPC.HasState and Enum and Enum.ModifierState then
        info.hasDisable = NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ROOTED)
            or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_STUNNED)
    else
        info.hasDisable = false
    end
    info.threat = info.offensiveWeight * (info.isVisible and 1 or 0.6)
    info.boundingRadius = safe_call(NPC.GetHullRadius, unit) or 24
    return info
end

local function collect_creeps(hero, team, radius)
    if not NPCs or not NPCs.InRadius then
        return {}
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local creeps = {}
    local enemyTeam = team == Enum.TeamNum.TEAM_RADIANT and Enum.TeamNum.TEAM_DIRE or Enum.TeamNum.TEAM_RADIANT
    for _, creep in ipairs(NPCs.InRadius(heroPos, radius, team, Enum.TeamType.TEAM_ENEMY, true, true)) do
        table.insert(creeps, {
            entity = creep,
            position = Entity.GetAbsOrigin(creep),
        })
    end
    for _, neutral in ipairs(NPCs.InRadius(heroPos, radius, Enum.TeamNum.TEAM_NEUTRAL, Enum.TeamType.TEAM_BOTH, true, true)) do
        table.insert(creeps, {
            entity = neutral,
            position = Entity.GetAbsOrigin(neutral),
        })
    end
    return creeps
end

local function evaluate_waves(hero, enemies, creeps)
    local team = Entity.GetTeamNum(hero.entity)
    local friendly = { size = 0, forwardDistance = 0 }
    local enemy = { size = 0, forwardDistance = 0 }
    local enemyFountain = nav.get_fountain(team == Enum.TeamNum.TEAM_RADIANT and Enum.TeamNum.TEAM_DIRE or Enum.TeamNum.TEAM_RADIANT)
    local friendlyFountain = nav.get_fountain(team)
    if enemyFountain and friendlyFountain then
        for _, creep in ipairs(creeps) do
            if creep.entity and NPC.IsLaneCreep and NPC.IsLaneCreep(creep.entity) then
                if Entity.IsSameTeam(creep.entity, hero.entity) then
                    friendly.size = friendly.size + 1
                    friendly.forwardDistance = friendly.forwardDistance + util.distance2d(Entity.GetAbsOrigin(creep.entity), enemyFountain)
                else
                    enemy.size = enemy.size + 1
                    enemy.forwardDistance = enemy.forwardDistance + util.distance2d(Entity.GetAbsOrigin(creep.entity), friendlyFountain)
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

function M.scan(dt)
    local hero = api.self()
    if not hero then
        return
    end
    if not Entity.IsAlive(hero) then
        bb:reset()
        return
    end
    local heroInfo = collect_hero_info(hero)
    bb:updateHero(heroInfo)
    local allies, enemies = collect_heroes(hero)
    local creeps = collect_creeps(hero, Entity.GetTeamNum(hero), bb.config.farmSearchRadius or 1600)
    local neutrals = {}
    local structures = {}
    bb:updateUnits(allies, enemies, creeps, neutrals, structures)
    local friendlyWave, enemyWave = evaluate_waves(heroInfo, enemies, creeps)
    bb:updateCreepPressure(friendlyWave, enemyWave)
    local threatScore, winChance, safe = threat.evaluate(heroInfo, allies, enemies)
    bb:updateThreat(threatScore, winChance, safe)
    bb.debugData.threat = {
        score = threatScore,
        win = winChance,
        safe = safe,
    }
end

return M
