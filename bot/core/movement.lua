local api = require("integration.uc_api")
local nav = require("core.nav")
local bb = require("core.blackboard")
local util = require("core.util")
local log = require("integration.log")

local M = {
    _lastChaseCheck = 0,
}

local _lastMovePos = nil
local _lastMoveTime = -math.huge
local _nextRoamTime = 0
local _laneWaypointIndex = 1
local _lastLaneUsed = nil

local function manual_override(now)
    if api.isPlayerControlling and api.isPlayerControlling() then
        local untilTime = now + 2
        bb:setUserOverride(untilTime)
        _nextRoamTime = untilTime
        return true
    end
    if bb:isUserOverride(now) then
        if _nextRoamTime < now + 0.1 then
            _nextRoamTime = now + 0.1
        end
        return true
    end
    return false
end

local function has_coordinates(pos)
    if not pos then
        return false
    end
    return pos.x ~= nil and pos.y ~= nil
end

local function should_move(now, pos)
    if not pos or not has_coordinates(pos) then
        return false
    end
    if not _lastMovePos then
        return true
    end
    local ok, distance = pcall(function()
        return (pos - _lastMovePos):Length2D()
    end)
    if not ok then
        distance = util.distance2d(pos, _lastMovePos)
    end
    return distance > 200 and (now - _lastMoveTime) > 0.5
end

local function next_lane_point(lane)
    if not lane then
        return nil
    end
    local waypoints = nav.get_lane_waypoints(lane)
    if not waypoints or #waypoints == 0 then
        return nil
    end
    if lane ~= _lastLaneUsed then
        _laneWaypointIndex = 1
        _lastLaneUsed = lane
    end
    local point = waypoints[_laneWaypointIndex]
    _laneWaypointIndex = _laneWaypointIndex + 1
    if _laneWaypointIndex > #waypoints then
        _laneWaypointIndex = 1
    end
    return point
end

function M.move_to(position)
    if not position or not has_coordinates(position) then
        return
    end
    local now = api.time()
    if manual_override(now) then
        return
    end
    if not should_move(now, position) then
        return
    end
    if api.moveTo(position) then
        bb:markMove(now)
        _lastMovePos = position
        _lastMoveTime = now
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

function M.roam(now, board)
    local currentTime = now or api.time()
    local state = board or bb
    if manual_override(currentTime) then
        return
    end
    if currentTime < _nextRoamTime then
        return
    end
    _nextRoamTime = currentTime + math.random(5, 10)

    local point = nil
    if state and state.laneAssignment then
        point = next_lane_point(state.laneAssignment)
    end
    if not point then
        point = nav.randomSafePos() or nav.nextRoamPoint()
    end
    if not point or not has_coordinates(point) then
        return
    end
    log.info(string.format("Roam: moving to new point (%.0f, %.0f)", point.x or 0, point.y or 0))
    M.move_to(point)
end

function M.update(now, board)
    local state = board or bb
    local currentTime = now or api.time()
    local mode = state and state.mode or "roam"

    if mode == "roam" then
        M.roam(currentTime, state)
        return
    end

    if mode == "retreat" then
        local retreatPos = nav.safeRetreat()
        if retreatPos then
            M.move_to(retreatPos)
        end
        return
    end
end

return M
