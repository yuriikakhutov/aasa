local scheduler = require("core.scheduler")
local perception = require("core.perception")
local selector = require("core.selector")
local actions = require("core.actions")
local movement = require("core.movement")
local bb = require("core.blackboard")

return function()
    local calls = {}

    local originalScan = perception.scan
    local originalDecide = selector.decide
    local originalExecute = actions.execute
    local originalMovement = movement.update

    perception.scan = function(now, state)
        table.insert(calls, "scan")
        state.visibleEnemies = {}
        state.visibleCreeps = {}
        state.hpRatio = 1
        state.manaRatio = 1
    end

    selector.decide = function(now, state)
        table.insert(calls, "decide")
        return "roam"
    end

    actions.execute = function(now, state)
        table.insert(calls, "actions")
    end

    movement.update = function(now, state)
        table.insert(calls, "movement")
    end

    if bb.reset then
        bb:reset()
    end

    scheduler.tick(10, bb)

    perception.scan = originalScan
    selector.decide = originalDecide
    actions.execute = originalExecute
    movement.update = originalMovement

    assert(#calls == 4, "Scheduler should invoke perception, selector, actions, and movement")
    return true
end
