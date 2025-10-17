local bb = require("core.blackboard")
local threat = require("core.threat")
local nav = require("core.nav")
local util = require("core.util")

local M = {}

function M.select_fight_target()
    local best = bb:bestEnemy()
    return best and best.entity or nil
end

function M.select_gank_target()
    for _, enemy in ipairs(bb.enemies or {}) do
        if enemy.isVisible and enemy.healthRatio < 0.7 and enemy.position then
            local danger = bb:getDangerAt(enemy.position)
            if danger < 0.4 then
                return enemy.entity
            end
        end
    end
    local best = bb:bestEnemy()
    return best and best.entity or nil
end

function M.should_commit(target)
    if not target then
        return false
    end
    local heroData = bb.heroData
    if not heroData then
        return false
    end
    local targetInfo = {
        health = Entity.GetHealth(target),
    }
    local killProb = threat.kill_probability(heroData, targetInfo)
    if killProb >= 0.6 then
        return true
    end
    return bb.winChance > (bb.config.fightEngageThreshold or 0.55)
end

function M.should_retreat()
    return bb:isUnderThreat()
end

function M.harass_target()
    local enemy = bb:bestEnemy()
    if not enemy then
        return nil
    end
    if enemy.healthRatio > 0.4 then
        return enemy.entity
    end
    return nil
end

function M.farm_target()
    return bb:safeFarmTarget()
end

return M
