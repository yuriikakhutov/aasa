local bb = require("core.blackboard")
local util = require("core.util")
local laning = require("core.laning")
local objective = require("core.objective")
local economy = require("core.economy")
local api = require("integration.uc_api")

local M = {}

local function utility_retreat()
    if not bb.hero then
        return 0
    end
    local threatScore = bb.threat or 0
    local hpFactor = 1 - bb.hpRatio
    if bb.hpRatio < (bb.config.retreatHpThreshold or 0.3) then
        hpFactor = hpFactor + 0.7
    end
    if threatScore > 0.7 then
        hpFactor = hpFactor + 0.5
    end
    return util.clamp(threatScore * 0.6 + hpFactor, 0, 2)
end

local function utility_fight()
    local win = bb.winChance or 0.5
    local target = bb:bestTargetInRange(bb.combatRange or 600)
    if not target then
        return 0
    end
    local score = win - (bb.threat or 0.3) * 0.5
    if bb.allyNearby then
        score = score + 0.15
    end
    return util.clamp(score, 0, 1.2)
end

local function utility_gank()
    for _, enemy in ipairs(bb.enemies or {}) do
        if enemy.isVisible and enemy.healthRatio < 0.6 then
            local danger = bb:getDangerAt(enemy.position)
            if danger < 0.4 then
                return 0.75
            end
        end
    end
    return 0
end

local function utility_push()
    if not bb.safe then
        return 0.1
    end
    if bb.waveAdvantage then
        return 0.6
    end
    return 0.25 + (bb.farmEfficiency or 0) * 0.1
end

local function utility_defend(time)
    local towers = api.towers() or {}
    for _, tower in ipairs(towers) do
        if tower and tower.isUnderAttack and tower.team == api.team() then
            return 0.85
        end
    end
    return 0.2
end

local function utility_farm()
    if not bb.safe then
        return 0.1
    end
    if bb:safeFarmTarget() then
        return 0.7
    end
    return bb.needGold and 0.5 or 0.35
end

local function utility_stack(time)
    local data = laning.stackOpportunity(time)
    if data then
        return 0.65
    end
    return 0
end

local function utility_pull(time)
    local data = laning.pullOpportunity(time)
    if data then
        return 0.62
    end
    return 0
end

local function utility_rune(time)
    local spot, spawn = laning.runeWindow(time)
    if spot then
        local eta = math.max((spawn or time) - time, 0)
        return util.clamp(0.9 - eta * 0.03, 0, 0.9)
    end
    return 0
end

local function utility_shop()
    local nextItem = bb:peekBuy()
    if not nextItem then
        return 0
    end
    local gold = api.currentGold()
    if gold >= 0.8 * 1000 then
        return 0.55
    end
    return 0.2
end

local function utility_heal()
    if bb:isLowResources() then
        return 0.8
    end
    return 0
end

local function utility_objective(time)
    if objective.objectiveWindow(time) then
        return 0.6
    end
    return 0.2
end

local function utility_roam()
    return 0.3 + (bb.dangerLevel or 0) * 0.1
end

local function fallback(scores)
    table.insert(scores, { mode = "roam", score = utility_roam() })
end

function M.decide(time)
    time = time or api.time()
    local scores = {
        { mode = "retreat", score = utility_retreat() },
        { mode = "heal", score = utility_heal() },
        { mode = "fight", score = utility_fight() },
        { mode = "gank", score = utility_gank() },
        { mode = "push", score = utility_push() },
        { mode = "defend", score = utility_defend(time) },
        { mode = "farm", score = utility_farm() },
        { mode = "stack", score = utility_stack(time) },
        { mode = "pull", score = utility_pull(time) },
        { mode = "rune", score = utility_rune(time) },
        { mode = "shop", score = utility_shop() },
        { mode = "objective", score = utility_objective(time) },
    }
    fallback(scores)
    table.sort(scores, function(a, b)
        return a.score > b.score
    end)
    local top = scores[1]
    bb:setMode(top.mode, time)
    return top.mode
end

return M
