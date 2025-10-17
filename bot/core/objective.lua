local api = require("integration.uc_api")
local nav = require("core.nav")
local movement = require("core.movement")
local combat = require("core.combat")
local bb = require("core.blackboard")
local log = require("integration.log")

local M = {}

local function tower_under_attack()
    local towers = api.towers() or {}
    local team = api.team()
    for _, tower in ipairs(towers) do
        if tower and tower.team == team and tower.isUnderAttack then
            return tower
        end
    end
    return nil
end

function M.pushLane(lane)
    local target = nav.rotateTo(lane or bb.laneAssignment or "safe")
    if target then
        log.debug("Pushing lane towards " .. tostring(target))
        movement.move_to(target)
        return true
    end
    return false
end

function M.defendTower()
    local tower = tower_under_attack()
    if not tower then
        return false
    end
    if api.tpReady() and api.distance(api.self(), tower.entity) > 4000 then
        api.useTP(tower.position)
    else
        movement.move_to(tower.position)
    end
    bb:updateDangerAt(tower.position, 0.8)
    return true
end

function M.roshan()
    local enemies = bb.enemies or {}
    if #enemies > 0 then
        return false
    end
    local allies = bb.allies or {}
    local ready = 0
    for _, ally in ipairs(allies) do
        if ally and ally.healthRatio and ally.healthRatio > 0.6 then
            ready = ready + 1
        end
    end
    if ready < 2 then
        return false
    end
    local pit = Vector(0, -2500, 0)
    movement.move_to(pit)
    combat.prepareBurst()
    return true
end

function M.objectiveWindow(time)
    if time % 300 < 30 then
        return "outpost"
    end
    if time % 480 < 40 then
        return "roshan"
    end
    return nil
end

return M
