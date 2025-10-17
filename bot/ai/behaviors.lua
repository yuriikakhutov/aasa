local bb = require("core.blackboard")
local nav = require("integration.nav")
local tactics = require("ai.tactics")
local api = require("integration.uc_api")

local M = {}

function M.retreat()
    local safePos = nav.get_safe_back_pos()
    local escapeAbility = nil
    if bb:canUse("item_force_staff") then
        escapeAbility = bb:getItem("item_force_staff")
    elseif bb:canUse("item_hurricane_pike") then
        escapeAbility = bb:getItem("item_hurricane_pike")
    end
    return {
        kind = "retreat",
        position = safePos,
        escape = escapeAbility,
    }
end

function M.fight()
    local target = tactics.select_fight_target()
    if not target then
        return { kind = "wait" }
    end
    return {
        kind = "fight",
        target = target,
        commit = tactics.should_commit(target),
    }
end

function M.roam()
    local point = nav.next_roam_point()
    return {
        kind = "move",
        position = point,
    }
end

function M.farm()
    local target = tactics.farm_target()
    if target then
        return {
            kind = "farm",
            target = target,
        }
    end
    return M.roam()
end

function M.heal()
    local hero = api.self()
    return {
        kind = "heal",
        hero = hero,
    }
end

function M.push()
    local target = nav.next_roam_point()
    return {
        kind = "push",
        position = target,
    }
end

return M
