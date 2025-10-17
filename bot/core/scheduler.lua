local perception = require("core.perception")
local selector = require("core.selector")
local actions = require("core.actions")
local movement = require("core.movement")
local bb = require("core.blackboard")
local api = require("integration.uc_api")

local M = {}

function M.tick(now, board)
    local currentTime = now or api.time()
    local state = board or bb

    perception.scan(currentTime, state)

    local mode = selector.decide(currentTime, state)
    state.mode = mode

    actions.execute(currentTime, state)
    movement.update(currentTime, state)
end

return M
