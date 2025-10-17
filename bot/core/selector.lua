local bb = require("core.blackboard")
local api = require("integration.uc_api")
local log = require("integration.log")

local M = {}

local _currentMode = "roam"
local _lockUntil = -math.huge

local function lock_duration()
    return math.random(3, 7)
end

local function choose_mode(state)
    if (state.hpRatio or 1) < 0.25 then
        return "retreat"
    end
    if state.visibleEnemies and #state.visibleEnemies > 0 then
        return "fight"
    end
    if state.visibleCreeps and #state.visibleCreeps > 0 then
        return "farm"
    end
    return "roam"
end

function M.decide(now, board)
    local state = board or bb
    local timeNow = now or api.time()

    if not state.mode then
        state.mode = _currentMode
    end

    if timeNow < _lockUntil then
        state:setMode(state.mode, timeNow)
        return state.mode
    end

    local nextMode = choose_mode(state)
    if nextMode ~= _currentMode then
        _currentMode = nextMode
        _lockUntil = timeNow + lock_duration()
        log.info(string.format("Selector: mode=%s", nextMode))
    else
        _lockUntil = timeNow + lock_duration()
    end

    state.mode = _currentMode
    state:setMode(_currentMode, timeNow)
    return _currentMode
end

return M
