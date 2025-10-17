local api = require("integration.uc_api")
local bb = require("core.blackboard")
local util = require("core.util")

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

local function ability_priority(name, data)
    local priority = 0
    if data.damage and data.damage > 0 then
        priority = priority + util.clamp(data.damage / 300, 0.1, 2.5)
    end
    if Ability.IsUltimate and Ability.IsUltimate(data.handle) then
        priority = priority + 2
    end
    if string.find(name, "stun") or string.find(name, "disable") or string.find(name, "hex") then
        priority = priority + 1.5
    end
    if string.find(name, "slow") then
        priority = priority + 0.5
    end
    if data.cooldown and data.cooldown > 30 then
        priority = priority + 0.4
    end
    return priority
end

local function is_ready(data)
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

local function offensive_filter(data)
    if not data then
        return false
    end
    local behavior = data.behavior or 0
    return has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
        or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT)
        or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET)
end

function M.cast(ability, target)
    if not ability then
        return false
    end
    return api.cast(ability, target)
end

function M.prioritized_spells(target)
    local result = {}
    if not bb.heroData or not bb.heroData.abilities then
        return result
    end
    for name, data in pairs(bb.heroData.abilities) do
        if offensive_filter(data) and is_ready(data) then
            table.insert(result, { handle = data.handle, priority = ability_priority(name, data) })
        end
    end
    table.sort(result, function(a, b)
        return a.priority > b.priority
    end)
    local handles = {}
    for _, entry in ipairs(result) do
        table.insert(handles, entry.handle)
    end
    return handles
end

function M.poke_spells(target)
    local result = {}
    if not bb.heroData or not bb.heroData.abilities then
        return result
    end
    for name, data in pairs(bb.heroData.abilities) do
        if offensive_filter(data) and is_ready(data) and (data.manaCost or 0) <= (bb.heroData.maxMana * 0.2) then
            table.insert(result, data.handle)
        end
    end
    return result
end

return M
