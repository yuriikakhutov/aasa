local bb = require("core.blackboard")
local nav = require("core.nav")
local tactics = require("ai.tactics")
local api = require("integration.uc_api")
local laning = require("core.laning")
local objective = require("core.objective")

local M = {}

function M.retreat()
    return {
        kind = "retreat",
        position = nav.safeRetreat(),
    }
end

function M.fight()
    local target = tactics.select_fight_target()
    if not target then
        return M.roam()
    end
    return {
        kind = "fight",
        target = target,
        commit = tactics.should_commit(target),
    }
end

function M.gank()
    local target = tactics.select_gank_target()
    if not target then
        return M.roam()
    end
    return {
        kind = "gank",
        target = target,
    }
end

function M.push()
    return {
        kind = "push",
        lane = bb.laneAssignment or select(1, laning.assign()),
    }
end

function M.defend()
    return {
        kind = "defend",
    }
end

function M.farm()
    local target = tactics.farm_target()
    return {
        kind = "farm",
        target = target,
    }
end

function M.stack()
    return {
        kind = "stack",
        data = laning.stackOpportunity(api.time()),
    }
end

function M.pull()
    return {
        kind = "pull",
        data = laning.pullOpportunity(api.time()),
    }
end

function M.rune()
    local spot = select(1, laning.runeWindow(api.time()))
    return {
        kind = "rune",
        spot = spot,
    }
end

function M.roam()
    return {
        kind = "roam",
        position = nav.nextRoamPoint(),
    }
end

function M.heal()
    return {
        kind = "heal",
    }
end

function M.shop()
    return {
        kind = "shop",
    }
end

function M.objective()
    local obj = objective.objectiveWindow(api.time())
    return {
        kind = "objective",
        objective = obj,
    }
end

return M
