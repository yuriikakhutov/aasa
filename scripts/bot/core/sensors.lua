---
-- Sensors: grabs the latest snapshot from UCZone and normalises it.
---

local Log = require("scripts.bot.core.logger")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Sensors = {}

local function safeCall(name, ...)
    local fn = UZ[name]
    if not fn then
        Log.warn("Missing adapter function: " .. tostring(name))
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        Log.error("Adapter call failed: " .. name .. " -> " .. tostring(result))
        return nil
    end
    return result
end

function Sensors.capture()
    local selfUnit = safeCall("self")
    if not selfUnit then
        return { valid = false }
    end

    local enemies = safeCall("enemyHeroes", 3000) or {}
    local allies = safeCall("allyHeroes", 3000) or {}
    local enemyCreeps = safeCall("enemyCreeps", 1800) or {}
    local allyCreeps = safeCall("allyCreeps", 1800) or {}
    local neutrals = safeCall("neutrals", 2000) or {}
    local runes = safeCall("runes") or {}
    local towers = safeCall("towers") or {}

    local team = safeCall("team") or "radiant"
    local fountain = safeCall("fountainPos", team)

    return {
        valid = true,
        self = selfUnit,
        time = safeCall("time") or 0,
        team = team,
        pos = safeCall("myPos") or { x = 0, y = 0 },
        enemies = enemies,
        allies = allies,
        enemyCreeps = enemyCreeps,
        allyCreeps = allyCreeps,
        neutrals = neutrals,
        runes = runes,
        towers = towers,
        roshan = safeCall("roshan"),
        abilities = safeCall("abilities") or {},
        items = safeCall("items") or {},
        hasAghanim = safeCall("hasAghanim") or false,
        fountainPos = fountain,
    }
end

return Sensors
