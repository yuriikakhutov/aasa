local api = require("integration.uc_api")
local bb = require("core.blackboard")
local util = require("core.util")
local nav = require("core.nav")

local bit = bit32 or bit

local M = {}

local function has_behavior(behavior, flag)
    if not behavior or not flag then
        return false
    end
    if bit then
        return bit.band(behavior, flag) ~= 0
    end
    return false
end

local function ability_ready(data)
    if not data or not data.handle then
        return false
    end
    if Ability.IsHidden and Ability.IsHidden(data.handle) then
        return false
    end
    if Ability.IsPassive and Ability.IsPassive(data.handle) then
        return false
    end
    if not Ability.IsReady(data.handle) then
        return false
    end
    if not Ability.IsOwnersManaEnough(data.handle) then
        return false
    end
    return true
end

local function offensive(data)
    if not data then
        return false
    end
    local behavior = data.behavior or 0
    return has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
        or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT)
        or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET)
end

local function score_ability(name, data)
    local score = 0
    if Ability.IsUltimate and Ability.IsUltimate(data.handle) then
        score = score + 2.5
    end
    if data.damage and data.damage > 0 then
        score = score + util.clamp(data.damage / 300, 0.2, 3.0)
    end
    if string.find(name, "stun") or string.find(name, "disable") or string.find(name, "hex") then
        score = score + 1.5
    end
    if string.find(name, "silence") then
        score = score + 1.2
    end
    if string.find(name, "slow") then
        score = score + 0.4
    end
    return score
end

local function gather_abilities(filter)
    local abilities = {}
    if not bb.heroData or not bb.heroData.abilities then
        return abilities
    end
    for name, data in pairs(bb.heroData.abilities) do
        if filter(name, data) then
            table.insert(abilities, { name = name, data = data, score = score_ability(name, data) })
        end
    end
    table.sort(abilities, function(a, b)
        return a.score > b.score
    end)
    return abilities
end

function M.predictCast(spell, target, projectileSpeed, castPoint, leadBase)
    if not target then
        return nil
    end
    leadBase = leadBase or 0.3
    projectileSpeed = projectileSpeed or 900
    castPoint = castPoint or 0
    local pos = nav.predictivePos(target, leadBase + castPoint)
    if not pos then
        return nil
    end
    if projectileSpeed > 0 then
        local hero = api.self()
        if hero then
            local heroPos = Entity.GetAbsOrigin(hero)
            local distance = util.distance2d(heroPos, pos)
            local travel = distance / projectileSpeed
            pos = nav.predictivePos(target, travel + castPoint) or pos
        end
    end
    return pos
end

function M.cast(ability, target)
    if not ability then
        return false
    end
    return api.cast(ability, target)
end

function M.prioritized_spells(target)
    local list = gather_abilities(function(name, data)
        return offensive(data) and ability_ready(data)
    end)
    local handles = {}
    for _, entry in ipairs(list) do
        table.insert(handles, entry.data.handle)
    end
    return handles
end

function M.poke_spells(target)
    local list = gather_abilities(function(name, data)
        return offensive(data) and ability_ready(data) and (data.manaCost or 0) <= (bb.heroData.maxMana * 0.2)
    end)
    local handles = {}
    for _, entry in ipairs(list) do
        table.insert(handles, entry.data.handle)
    end
    return handles
end

function M.burstCombo(target)
    if not target then
        return
    end
    local spells = M.prioritized_spells(target)
    for _, ability in ipairs(spells) do
        local name = Ability.GetName and Ability.GetName(ability) or ""
        if has_behavior(Ability.GetBehavior and Ability.GetBehavior(ability), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) then
            local pos = M.predictCast(ability, target)
            if pos then
                api.cast(ability, pos)
            end
        else
            api.cast(ability, target)
        end
    end
end

function M.finishSecure(target)
    if not target then
        return false
    end
    if not Entity.IsAlive(target) then
        return false
    end
    local hp = Entity.GetHealth(target)
    local damage = (bb.heroData.attackDamage or 0) * 2 + (bb.heroData.comboDamage or 0)
    if damage >= hp then
        api.attack(target)
        return true
    end
    return false
end

return M
