local UZ = require("scripts.bot.vendors.uczone_adapter")
local Log = require("scripts.bot.core.log")

---@class SensorSnapshot
---@field time number
---@field selfUnit table
---@field allies table
---@field enemies table
---@field neutrals table
---@field runes table
---@field roshan table|nil
---@field projectiles table
---@field debuffs table

local Sensors = {}

---Collects a fresh snapshot of the current game state.
---@return SensorSnapshot|nil
function Sensors.capture()
    local ok, result = pcall(function()
        local selfUnit = UZ.self()
        if not selfUnit then
            return nil
        end
        return {
            time = UZ.time(),
            selfUnit = selfUnit,
            allies = UZ.allyHeroes(2500),
            enemies = UZ.enemyHeroes(2500),
            neutrals = UZ.neutrals(2500),
            runes = UZ.runes(),
            roshan = UZ.roshan(),
            projectiles = {},
            debuffs = selfUnit.debuffs or {}
        }
    end)

    if not ok then
        Log.error("Sensors.capture failed: " .. tostring(result))
        return nil
    end

    return result
end

return Sensors
