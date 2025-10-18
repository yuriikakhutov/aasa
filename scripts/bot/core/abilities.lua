---
-- Ability orchestration with basic targeting heuristics routed through the
-- order coalescer.
---

local Log = require("scripts.bot.core.logger")

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
    if ability.isPassive or ability.behavior == "PASSIVE" then
        return false
    end
    return true
end

local function abilitySignature(ability)
    return tostring(ability.name or ability.id or ability.handle)
end

local function evaluateTargetAbility(ability, tactics, orders)
    if ability.behavior == BEHAVIOR.UNIT_TARGET then
        return (tactics.focus or orders.attackTarget)
    elseif ability.behavior == BEHAVIOR.POINT then
        local focus = tactics.focus or orders.attackTarget
        return focus and focus.pos
    elseif ability.behavior == BEHAVIOR.NO_TARGET then
        return nil
    end
end

local function queueCast(coalescer, UZ, ability, payload)
    if not coalescer or not UZ then
        return false
    end
    return coalescer:queue("cast", abilitySignature(ability), UZ.cast, ability, payload)
end

function Abilities.execute(bb, coalescer, UZ)
    local sensors = bb.sensors or {}
    local abilities = sensors.abilities or {}
    local tactics = bb.tactics or {}
    local issued = false

    local heroModule = bb.heroModule
    if heroModule and heroModule.selectAbility then
        local ability, payload = heroModule.selectAbility(bb)
        if ability and isReady(ability, sensors.self) then
            issued = queueCast(coalescer, UZ, ability, payload)
            if issued then
                Log.debug("Hero module queued ability %s", tostring(ability.name))
                return true
            end
        end
    end

    for _, ability in ipairs(abilities) do
        if isReady(ability, sensors.self) then
            local payload = evaluateTargetAbility(ability, tactics, bb.micro or {})
            if queueCast(coalescer, UZ, ability, payload) then
                issued = true
                break
            end
        end
    end

    return issued
end

return Abilities
