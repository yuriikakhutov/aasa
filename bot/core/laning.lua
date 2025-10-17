local api = require("integration.uc_api")
local bb = require("core.blackboard")
local nav = require("core.nav")
local log = require("integration.log")

local M = {}

local ROLES = { "carry", "mid", "off", "soft", "hard" }

local function detect_role()
    if bb.role then
        return bb.role
    end
    if bb.heroData and bb.heroData.attackRange and bb.heroData.attackRange > 400 then
        return "carry"
    end
    if bb.heroData and bb.heroData.isMid then
        return "mid"
    end
    local allies = bb.allies or {}
    if #allies <= 1 then
        return "mid"
    end
    return "off"
end

local function lane_from_position(pos)
    if not pos then
        return "mid"
    end
    local midDist = math.abs(pos.x) + math.abs(pos.y)
    if math.abs(pos.x) > math.abs(pos.y) then
        if pos.x > 0 then
            return "off"
        else
            return "safe"
        end
    end
    if midDist < 2000 then
        return "mid"
    end
    if pos.y > 0 then
        return "off"
    end
    return "safe"
end

function M.assign()
    if bb.laneAssignment then
        return bb.laneAssignment, bb.role
    end
    local hero = api.self()
    local pos = hero and Entity.GetAbsOrigin and Entity.GetAbsOrigin(hero) or Vector(0, 0, 0)
    local role = detect_role()
    local lane = lane_from_position(pos)
    if role == "mid" then
        lane = "mid"
    elseif role == "carry" then
        lane = lane == "mid" and "safe" or lane
    elseif role == "hard" then
        lane = "off"
    end
    bb:setLaneAssignment(lane, role)
    log.info("Assigned lane=" .. lane .. " role=" .. role)
    return lane, role
end

local function rune_cycle(time)
    local interval = bb.config.runeInterval or 120
    local prep = bb.config.runePrepTime or 10
    local nextRune = math.floor(time / interval + 1) * interval
    return nextRune, nextRune - prep
end

function M.runeWindow(time)
    local spawn, prep = rune_cycle(time)
    if time >= prep and time < spawn + 5 then
        local lane, role = M.assign()
        if role == "mid" then
            return nav.runeSpot("water1"), spawn
        end
        if (spawn / 60) % 2 == 0 then
            return nav.runeSpot("top"), spawn
        else
            return nav.runeSpot("bottom"), spawn
        end
    end
    return nil, spawn
end

local function is_lane_dangerous()
    return bb:isUnderThreat() or bb.threat > 0.7
end

function M.shouldLeaveLane(time)
    if not bb.hero then
        return false
    end
    if is_lane_dangerous() then
        return true
    end
    if bb.waveAdvantage and bb.needGold then
        return false
    end
    if bb:canRotate(time) then
        return true
    end
    return false
end

function M.pullOpportunity(time)
    local lane = bb.laneAssignment or "safe"
    local data = nav.pullInfo(lane == "safe" and "small" or "mid")
    if not data then
        return nil
    end
    local seconds = time % 60
    local window = bb.config.pullPrepWindow or 8
    if seconds >= data.pullTime - window and seconds <= data.pullTime + 1 then
        return data
    end
    return nil
end

function M.stackOpportunity(time)
    local data = nav.stackInfo("ancients")
    if not data then
        return nil
    end
    local seconds = time % 60
    local window = bb.config.stackPrepWindow or 8
    if seconds >= data.stackTime - window and seconds <= data.stackTime + 1 then
        return data
    end
    return nil
end

function M.prepareRotation(time)
    local nextRune = select(2, M.runeWindow(time))
    if nextRune and nextRune - time < 35 then
        bb:scheduleRotation(nextRune + 5)
    end
end

return M
