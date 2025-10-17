local bb = require("core.blackboard")
local util = require("core.util")

local M = {}

local function utility_retreat()
    if not bb.hero then
        return 0
    end
    local threatScore = bb.threat or 0
    local hpFactor = 1 - bb.hpRatio
    if bb.hpRatio < (bb.config.retreatHpThreshold or 0.3) then
        hpFactor = hpFactor + 0.5
    end
    return util.clamp(threatScore * 0.7 + hpFactor, 0, 1.5)
end

local function utility_fight()
    local win = bb.winChance or 0.5
    local hasTarget = bb:bestTargetInRange(bb.combatRange) ~= nil
    local threatScore = bb.threat or 0
    if not hasTarget then
        return 0
    end
    local offensive = win * 0.8 - threatScore * 0.4
    if bb.allyNearby then
        offensive = offensive + 0.1
    end
    return util.clamp(offensive, 0, 1)
end

local function utility_roam()
    if bb.safe and bb.seenWeakEnemy then
        return 0.65
    end
    if bb.safe and bb.needGold then
        return 0.5
    end
    return bb.safe and 0.3 or 0
end

local function utility_farm()
    if not bb.safe then
        return 0
    end
    local target = bb:safeFarmTarget()
    if target then
        return 0.7
    end
    return bb.needGold and 0.5 or 0.3
end

local function utility_heal()
    if bb:isLowResources() and bb.healReady then
        return 0.8
    end
    return 0.0
end

local function utility_push()
    if not bb.safe then
        return 0
    end
    if bb.waveAdvantage then
        return 0.55
    end
    return 0.2
end

function M.decide(time)
    local scores = {
        { mode = "retreat", score = utility_retreat() },
        { mode = "heal", score = utility_heal() },
        { mode = "fight", score = utility_fight() },
        { mode = "farm", score = utility_farm() },
        { mode = "push", score = utility_push() },
        { mode = "roam", score = utility_roam() },
    }
    table.sort(scores, function(a, b)
        return a.score > b.score
    end)
    local top = scores[1]
    bb.events.lastMode = top.mode
    return top.mode
end

return M
