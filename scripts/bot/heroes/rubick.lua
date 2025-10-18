local Log = require("scripts.bot.core.log")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Rubick = {}

function Rubick.configure(blackboard)
    blackboard.hero = {
        name = "rubick",
        preferences = {
            engageRange = 800,
            avoidBlinkIfLongSpell = true
        },
        stolen = {}
    }
end

local HIGH_VALUE = {
    enigma_black_hole = true,
    tidehunter_ravage = true,
    magnataur_reverse_polarity = true,
    sandking_epicenter = true,
    faceless_void_chronosphere = true,
    earthshaker_echo_slam = true
}

local function updateStolenMemory(blackboard)
    local hero = blackboard.hero
    if not hero or hero.name ~= "rubick" then
        return
    end
    for _, ability in ipairs(UZ.abilities()) do
        if ability.name and ability.name:find("rubick_spell_steal") == nil and not ability.isDefault then
            local record = hero.stolen[ability.name] or {}
            record.castRange = ability.castRange
            record.behavior = ability.behavior
            record.cdReadyAt = (ability.cd or 0) + UZ.time()
            hero.stolen[ability.name] = record
        end
    end
end

local function pickStolen(hero)
    local best, bestScore
    for name, data in pairs(hero.stolen) do
        local ready = not data.cdReadyAt or data.cdReadyAt <= UZ.time()
        if ready then
            local score = HIGH_VALUE[name] and 3 or 1
            if data.castRange and data.castRange > 900 then
                score = score + 1
            end
            if not best or score > bestScore then
                best = name
                bestScore = score
            end
        end
    end
    return best
end

function Rubick.update(blackboard)
    updateStolenMemory(blackboard)
end

function Rubick.shouldBlink(blackboard, targetRange)
    local hero = blackboard.hero
    if not hero or not hero.preferences.avoidBlinkIfLongSpell then
        return true
    end

    local best = pickStolen(hero)
    if not best then
        return true
    end
    local data = hero.stolen[best]
    if data and data.castRange and data.castRange > targetRange then
        return false
    end
    return true
end

return Rubick
