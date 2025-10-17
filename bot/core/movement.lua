local api = require("integration.uc_api")
local nav = require("core.nav")
local bb = require("core.blackboard")
local util = require("core.util")
local log = require("integration.log")

local M = {
    _lastChaseCheck = 0,
    _lastMovePos = nil,
    _lastMoveTime = -math.huge,
    _lastDestination = nil,
}

local function manual_override(now)
    if api.isPlayerControlling and api.isPlayerControlling() then
        local untilTime = now + 2
        bb:setUserOverride(untilTime)
        return true
    end
    return bb:isUserOverride(now)
end

local function should_issue_move(pos, now)
    if not pos then
        return false
    end
    if manual_override(now) then
        return false
    end
    if not M._lastDestination then
        return true
    end
    local distance = util.distance2d(pos, M._lastDestination)
    if distance > 100 then
        return true
    end
    if (now - (M._lastMoveTime or -math.huge)) > 0.5 then
        return true
    end
    return false
end

function M.move_to(position)
    if not position then
        return
    end
    local now = api.time()
    if not should_issue_move(position, now) then
        return
    end
    if api.moveTo(position) then
        bb:markMove(now)
        M._lastMovePos = position
        M._lastDestination = position
        M._lastMoveTime = now
        log.info(string.format("Move → x:%.0f y:%.0f", position.x or 0, position.y or 0))
    end
end

function M.attack(target)
    if not target then
        return
    end
    local now = api.time()
    if manual_override(now) then
        return
    end
    if api.attack(target) then
        bb:markAttack(now)
    end
end

function M.hold()
    local now = api.time()
    if manual_override(now) then
        return
    end
    api.hold()
end

function M.stop()
    local now = api.time()
    if manual_override(now) then
        return
    end
    api.stop()
end

function M.chaseAggressive(target)
    if not target or not api.isAlive(target) then
        return
    end
    local lead = nav.predictivePos(target, 0.6)
    if lead then
        M.move_to(lead)
    else
        M.move_to(Entity.GetAbsOrigin(target))
    end
    local distance = api.distance(api.self(), target)
    if distance < (bb.combatRange or 600) then
        M.attack(target)
    end
end

local function orbwalk_step(target)
    if not target then
        return
    end
    M.attack(target)
    local hero = api.self()
    if not hero then
        return
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local targetPos = nav.predictivePos(target, 0.2) or Entity.GetAbsOrigin(target)
    if not heroPos or not targetPos then
        return
    end
    local direction = util.normalize(targetPos - heroPos)
    local offset = direction * (bb.config.orbwalkMoveStep or 120)
    M.move_to(heroPos + offset)
end

function M.kite(target)
    orbwalk_step(target)
end

function M.rotate(area)
    local point = nav.rotateTo(area)
    if point then
        M.move_to(point)
    end
end

function M.safe_retreat()
    local pos = nav.safeRetreat()
    if pos then
        M.move_to(pos)
    end
end

function M.farmRoute()
    local id = select(1, bb:bestFarmNode())
    if id then
        local camp = nav.stackInfo(id) or nav.pullInfo(id)
        if camp and camp.approach then
            M.move_to(camp.approach)
            return
        end
    end
    M.roam()
end

function M.roam()
    local point = nav.randomSafePos() or nav.nextRoamPoint()
    if not point then
        return
    end
    M.move_to(point)
end

return M
