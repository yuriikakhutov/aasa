---
-- Rubick specific behaviour: manages stolen spells and smart casting.
---

local Log = require("scripts.bot.core.logger")

local Rubick = {}

local HIGH_VALUE = {
    black_hole = 5,
    magnus_reverse_polarity = 4.8,
    enigma_black_hole = 5,
    faceless_void_chronosphere = 4.5,
    tidehunter_ravage = 4.6,
    sven_storm_bolt = 3.5,
    earthshaker_echo_slam = 5,
    sandking_burrowstrike = 4,
    pudge_meat_hook = 3.8,
    lion_impale = 3.5,
}

local function normaliseName(name)
    return name and string.gsub(string.lower(name), "%W", "_") or ""
end

local function isBlink(ability)
    local name = normaliseName(ability and ability.name)
    return name ~= "" and string.find(name, "blink") ~= nil
end

local function updateStolen(memory, sensors)
    memory.stolenAbilities = memory.stolenAbilities or {}
    for _, ability in ipairs(sensors.abilities or {}) do
        if ability.isStolen or (ability.name and ability.name ~= "rubick_spell_steal" and ability.owner ~= sensors.self) then
            local key = ability.name
            local entry = memory.stolenAbilities[key] or {}
            entry.castRange = ability.castRange or entry.castRange
            entry.behavior = ability.behavior or entry.behavior
            if ability.cd and ability.cd > 0 then
                entry.cdReadyAt = sensors.time + ability.cd
            else
                entry.cdReadyAt = sensors.time
            end
            memory.stolenAbilities[key] = entry
        end
    end
end

local function chooseAbility(memory, sensors)
    local bestAbility
    local bestScore = 0
    local longestRange = 0
    for _, ability in ipairs(sensors.abilities or {}) do
        if ability.isStolen or (ability.name and ability.name ~= "rubick_spell_steal" and ability.owner ~= sensors.self) then
            local entry = memory.stolenAbilities and memory.stolenAbilities[ability.name]
            local ready = (ability.cd or 0) <= 0.1 and (not entry or sensors.time >= (entry.cdReadyAt or 0) - 0.1)
            if ready then
                local range = ability.castRange or 0
                if range > longestRange then
                    longestRange = range
                end
                local score = HIGH_VALUE[normaliseName(ability.name)] or range / 1000
                if score > bestScore then
                    bestScore = score
                    bestAbility = ability
                end
            end
        end
    end
    return bestAbility, longestRange
end

local function pickPayload(ability, tactics, orders)
    if not ability then
        return nil
    end
    if ability.behavior == "UNIT_TARGET" then
        return (tactics.focus and tactics.focus) or orders.attackTarget
    elseif ability.behavior == "POINT" then
        local target = tactics.focus and tactics.focus.pos or orders.move
        return target
    end
    return nil
end

function Rubick.init(bb)
    bb.memory = bb.memory or {}
    bb.memory.stolenAbilities = bb.memory.stolenAbilities or {}
end

function Rubick.beforeAbility(bb)
    bb.validators = bb.validators or {}
    bb.validators.rubick = bb.validators.rubick or {}
end

function Rubick.selectAbility(bb)
    local sensors = bb.sensors or {}
    if not sensors.valid then
        return nil
    end
    local memory = bb.memory
    updateStolen(memory, sensors)

    local ability, longestRange = chooseAbility(memory, sensors)
    if not ability then
        return nil
    end

    local abilityRange = ability.castRange or 0
    local blink = isBlink(ability)
    local danger = 0
    if bb.danger and bb.danger.scorePosition and sensors.pos then
        danger = bb.danger:scorePosition(sensors.pos)
    end

    bb.validators = bb.validators or {}
    bb.validators.rubick = bb.validators.rubick or {}
    table.insert(bb.validators.rubick, {
        usedBlink = blink,
        safeCastRange = longestRange,
        blinkRange = abilityRange,
        dangerScore = danger,
    })

    if blink and longestRange > abilityRange then
        Log.debug("Skipping blink due to longer range alternative")
        return nil
    end

    local payload = pickPayload(ability, bb.tactics or {}, bb.micro or {})
    return ability, payload
end

return Rubick
