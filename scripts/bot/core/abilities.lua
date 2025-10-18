---
-- Ability orchestration with basic targeting heuristics.
---

local Log = require("scripts.bot.core.log")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Abilities = {}

local BEHAVIOR = {
    NO_TARGET = "NO_TARGET",
    UNIT_TARGET = "UNIT_TARGET",
    POINT = "POINT",
}

local function isReady(ability, selfUnit)
    if not ability then
        return false
    end
    if ability.cd and ability.cd > 0.1 then
        return false
    end
    if ability.mana and selfUnit and selfUnit.mana and ability.mana > selfUnit.mana then
        return false
    end
    return true
end

local function cast(ability, payload)
    if not ability or not ability.handle then
        return false
    end
    local ok, result = pcall(UZ.cast, ability, payload)
    if not ok then
        Log.error("Failed to cast " .. tostring(ability.name) .. ": " .. tostring(result))
        return false
    end
    return result
end

local function evaluateTargetAbility(ability, tactics)
    if ability.behavior == BEHAVIOR.UNIT_TARGET then
        return tactics.focus
    elseif ability.behavior == BEHAVIOR.POINT then
        return tactics.focus and tactics.focus.pos
    elseif ability.behavior == BEHAVIOR.NO_TARGET then
        return nil
    end
end

function Abilities.execute(bb, orders)
    local sensors = bb.sensors or {}
    local abilities = sensors.abilities or {}
    local tactics = bb.tactics or {}

    local heroModule = bb.heroModule
    if heroModule and heroModule.selectAbility then
        local ability, payload = heroModule.selectAbility(bb, orders)
        if ability and isReady(ability, sensors.self) then
            if cast(ability, payload) then
                return true
            end
        end
    end

    for _, ability in ipairs(abilities) do
        if not ability.isPassive and isReady(ability, sensors.self) then
            local payload = evaluateTargetAbility(ability, tactics)
            if ability.behavior == BEHAVIOR.UNIT_TARGET and not payload then
                payload = orders.attackTarget
            end
            if cast(ability, payload) then
                return true
            end
        end
    end
    return false
end

return Abilities
