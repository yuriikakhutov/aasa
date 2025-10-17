local util = require("core.util")
local api = require("integration.uc_api")
local grid = require("integration.nav")

local M = {
    _roamIndex = 1,
}

local SAFE_TRIANGLES = {
    Vector(-4300, -4300, 0),
    Vector(4300, 4300, 0),
    Vector(-4300, 3600, 0),
    Vector(3600, -4300, 0),
}

local FOUNTAINS = {
    [2] = Vector(-7200, -6600, 0),
    [3] = Vector(7200, 6600, 0),
}

local RUNE_SPOTS = {
    top = Vector(-2288, 1856, 0),
    bottom = Vector(2304, -1856, 0),
    water1 = Vector(0, -192, 0),
    water2 = Vector(-256, 256, 0),
}

local JUKE_POINTS = {
    Vector(-1200, 3400, 0),
    Vector(1500, -2500, 0),
    Vector(-3000, -800, 0),
    Vector(2800, 600, 0),
}

local LANE_PATHS = {
    safe = {
        Vector(-6200, -3800, 0),
        Vector(-4800, -2000, 0),
        Vector(-2800, -200, 0),
        Vector(-400, 1200, 0),
    },
    off = {
        Vector(6200, 3800, 0),
        Vector(4400, 2000, 0),
        Vector(2000, 200, 0),
        Vector(400, -1200, 0),
    },
    mid = {
        Vector(-5200, 0, 0),
        Vector(-2600, 0, 0),
        Vector(0, 0, 0),
        Vector(2600, 0, 0),
        Vector(5200, 0, 0),
    },
}

local ROAM_GRAPH = {
    Vector(-3600, -3600, 0),
    Vector(-1200, -2400, 0),
    Vector(-400, 0, 0),
    Vector(1200, 2400, 0),
    Vector(3600, 3600, 0),
    Vector(2000, -1200, 0),
    Vector(-1800, 1600, 0),
}

local PULL_DATA = {
    small = { pullTime = 53, approach = Vector(-4500, 3400, 0), leash = Vector(-4700, 3200, 0) },
    mid = { pullTime = 54, approach = Vector(4300, -3600, 0), leash = Vector(4500, -3300, 0) },
}

local STACK_DATA = {
    ancients = { stackTime = 53.5, approach = Vector(-3000, 3600, 0), exit = Vector(-3400, 4000, 0) },
    hard = { stackTime = 53.8, approach = Vector(3400, -2800, 0), exit = Vector(3800, -3000, 0) },
}

local JUNGLE_CAMPS = {
    radiant_small = { position = Vector(-4300, 3500, 0), danger = 0.2 },
    radiant_medium = { position = Vector(-2000, 3500, 0), danger = 0.3 },
    radiant_large = { position = Vector(-3200, 4800, 0), danger = 0.35 },
    dire_small = { position = Vector(4300, -3500, 0), danger = 0.2 },
    dire_medium = { position = Vector(2000, -3500, 0), danger = 0.3 },
    dire_large = { position = Vector(3200, -4800, 0), danger = 0.35 },
}

local function nearest(list, pos)
    local best, bestDist = nil, math.huge
    for _, point in ipairs(list) do
        local dist = util.distance2d(pos, point)
        if dist < bestDist then
            best = point
            bestDist = dist
        end
    end
    return best, bestDist
end

function M.closestWaypoint(pos)
    local all = {}
    for _, lane in pairs(LANE_PATHS) do
        for _, p in ipairs(lane) do
            table.insert(all, p)
        end
    end
    return nearest(all, pos)
end

function M.safeRetreat()
    local hero = api.self()
    if not hero then
        return SAFE_TRIANGLES[1]
    end
    local fountain = grid.get_safe_back_pos and grid.get_safe_back_pos()
    if fountain then
        return fountain
    end
    local team = Entity.GetTeamNum(hero)
    return FOUNTAINS[team] or SAFE_TRIANGLES[1]
end

function M.pathTo(target)
    local hero = api.self()
    if not hero or not target then
        return { target }
    end
    local origin = Entity.GetAbsOrigin(hero)
    return grid.find_path(origin, target)
end

function M.rotateTo(targetArea)
    local hero = api.self()
    if not hero then
        return nil
    end
    local destination = targetArea
    if type(targetArea) == "string" then
        local lane = LANE_PATHS[targetArea]
        if lane then
            destination = lane[#lane]
        end
    end
    if not destination then
        destination = SAFE_TRIANGLES[math.random(1, #SAFE_TRIANGLES)]
    end
    local path = M.pathTo(destination)
    return path[#path]
end

function M.nextRoamPoint()
    if #ROAM_GRAPH == 0 then
        return SAFE_TRIANGLES[1]
    end
    local point = ROAM_GRAPH[M._roamIndex]
    M._roamIndex = M._roamIndex + 1
    if M._roamIndex > #ROAM_GRAPH then
        M._roamIndex = 1
    end
    return point
end

function M.pullInfo(campId)
    return PULL_DATA[campId]
end

function M.stackInfo(campId)
    return STACK_DATA[campId]
end

function M.predictivePos(unit, leadSec)
    if not unit then
        return nil
    end
    leadSec = leadSec or 0.4
    if Entity.GetAbsOrigin and Entity.GetVelocity then
        local pos = Entity.GetAbsOrigin(unit)
        local vel = Entity.GetVelocity(unit) or Vector(0, 0, 0)
        return pos + vel * leadSec
    end
    if Entity.GetAbsOrigin then
        return Entity.GetAbsOrigin(unit)
    end
    return nil
end

function M.randomSafePos()
    local count = #SAFE_TRIANGLES
    if count == 0 then
        return nil
    end
    return SAFE_TRIANGLES[math.random(1, count)]
end

function M.runeSpot(which)
    return RUNE_SPOTS[which]
end

function M.jukePoint()
    return JUKE_POINTS[math.random(1, #JUKE_POINTS)]
end

function M.nearestShopPos(shopType)
    local shop = api.nearestShop(shopType)
    if shop and shop.position then
        return shop.position
    end
    return SAFE_TRIANGLES[1]
end

function M.getLaneWaypoints(lane)
    return LANE_PATHS[lane]
end

function M.getJungleCamp(id)
    return JUNGLE_CAMPS[id]
end

function M.getFountain(team)
    return FOUNTAINS[team]
end

return M
