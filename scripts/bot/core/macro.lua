---
-- Macro planner: chooses the primary objective based on utility weights.
---

local Log = require("scripts.bot.core.logger")
local Utility = require("scripts.bot.core.utility")
local Objectives = require("scripts.bot.core.objectives")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Macro = {}

local function callSafe(name, ...)
    local fn = UZ[name]
    if not fn then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    Log.error("Macro adapter call failed: " .. tostring(name) .. " -> " .. tostring(result))
    return nil
end

local function selectHighestScore(scores)
    local bestKey, bestScore = nil, -math.huge
    for key, score in pairs(scores) do
        if score > bestScore then
            bestScore = score
            bestKey = key
        end
    end
    return bestKey, bestScore
end

local function defaultFarmPosition(team)
    if team == "dire" then
        return { x = -3500, y = 2500 }
    end
    return { x = 3500, y = -2500 }
end

function Macro.plan(bb)
    local sensors = bb.sensors or {}
    local scores = Utility.evaluate(bb)
    local choice = selectHighestScore(scores)

    if not choice then
        return Objectives.new(Objectives.Types.FarmSafe, { position = defaultFarmPosition(sensors.team) })
    end

    if choice == "retreat" then
        local pos = callSafe("safeRetreatPoint") or callSafe("fountainPos", sensors.team)
        return Objectives.new(Objectives.Types.Retreat, { position = pos })
    elseif choice == "farm" then
        local pos = defaultFarmPosition(sensors.team)
        return Objectives.new(Objectives.Types.FarmSafe, { position = pos })
    elseif choice == "push" then
        return Objectives.new(Objectives.Types.PushTier, { lane = "mid" })
    elseif choice == "defend" then
        return Objectives.new(Objectives.Types.DefendTier, { structure = "tier2" })
    elseif choice == "gank" then
        local target = sensors.enemies and sensors.enemies[1]
        if target and target.pos then
            return Objectives.new(Objectives.Types.GankHero, { targetId = target.id or target.name, position = target.pos })
        end
        return Objectives.new(Objectives.Types.FarmAggressive, { position = defaultFarmPosition(sensors.team) })
    elseif choice == "rune" then
        local rune = sensors.runes and sensors.runes[1]
        if rune and rune.pos then
            return Objectives.new(Objectives.Types.ControlRune, { position = rune.pos, runeType = rune.type })
        end
        return Objectives.new(Objectives.Types.ControlRune, {})
    elseif choice == "roshan" then
        local rosh = callSafe("roshan")
        return Objectives.new(Objectives.Types.TakeRoshan, { position = rosh and rosh.pos })
    elseif choice == "regroup" then
        return Objectives.new(Objectives.Types.Regroup, { position = callSafe("safeRetreatPoint") })
    end

    return Objectives.new(Objectives.Types.FarmSafe, { position = defaultFarmPosition(sensors.team) })
end

return Macro
