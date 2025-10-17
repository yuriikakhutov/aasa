local bb = require("core.blackboard")
local threat = require("core.threat")
local nav = require("integration.nav")

local M = {}

function M.select_fight_target()
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

function M.push_position()
    local target = bb:bestEnemy()
    if target and target.position then
        return target.position
    end
    return nav and nav.next_roam_point and nav.next_roam_point() or nil
end

return M
