---
-- Tactics: short term combat planning given current surroundings.
---

local Log = require("scripts.bot.core.log")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Tactics = {}

local function heroHealth(unit)
    if not unit or not unit.health or not unit.maxHealth or unit.maxHealth == 0 then
        return 1
    end
    return unit.health / unit.maxHealth
end

local function pickFocusTarget(sensors)
    local best, bestScore
    for _, enemy in ipairs(sensors.enemies or {}) do
        local score = (enemy.isCore and 1.5 or 1.0) + (enemy.level or 1) * 0.05
        score = score - heroHealth(enemy)
        if not best or score > bestScore then
            best = enemy
            bestScore = score
        end
    end
    return best
end

function Tactics.plan(bb)
    local sensors = bb.sensors or {}
    if not sensors.valid then
        return { mode = "idle" }
    end

    local selfHealth = heroHealth(sensors.self)
    local enemyCount = #(sensors.enemies or {})

    if selfHealth < 0.35 then
        return {
            mode = "disengage",
            retreatPoint = UZ.safeRetreatPoint() or UZ.fountainPos(sensors.team),
            urgency = 1.0,
        }
    end

    if enemyCount == 0 then
        return {
            mode = "idle",
            urgency = 0.2,
        }
    end

    local focus = pickFocusTarget(sensors)
    return {
        mode = enemyCount >= 3 and "skirmish" or "duel",
        focus = focus,
        urgency = 0.7,
        desiredRange = focus and (focus.attackRange or 150) + 100 or 300,
    }
end

return Tactics
