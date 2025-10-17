local selector = require("core.selector")
local bb = require("core.blackboard")

return function()
    local originalRandom = math.random
    math.random = function()
        return 3
    end

    bb:reset()
    bb.visibleEnemies = {}
    bb.visibleCreeps = {}
    bb.hpRatio = 1

    local mode = selector.decide(0, bb)
    assert(mode == "roam", "expected default roam mode")

    bb.visibleCreeps = { { entity = {} } }
    bb.visibleEnemies = {}
    bb.hpRatio = 1
    mode = selector.decide(4, bb)
    assert(mode == "farm", "expected farm when creeps are visible")

    bb.visibleEnemies = { { entity = {} } }
    bb.visibleCreeps = {}
    mode = selector.decide(8, bb)
    assert(mode == "fight", "expected fight when enemies are visible")

    bb.hpRatio = 0.1
    bb.visibleEnemies = {}
    mode = selector.decide(12, bb)
    assert(mode == "retreat", "expected retreat when health is low")

    math.random = originalRandom
    return true
end
