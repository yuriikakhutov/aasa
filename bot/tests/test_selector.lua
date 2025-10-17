local selector = require("core.selector")
local bb = require("core.blackboard")

return function()
    bb:reset()
    bb.safe = false
    bb.hpRatio = 0.2
    bb.threat = 1.1
    local mode = selector.decide(0)
    assert(mode == "retreat", "expected retreat when under threat")

    bb.safe = true
    bb.hpRatio = 0.8
    bb.threat = 0.2
    bb.winChance = 0.7
    local original = bb.bestTargetInRange
    function bb:bestTargetInRange()
        return {}
    end
    mode = selector.decide(1)
    assert(mode == "fight", "expected fight when winning")

    bb.safe = true
    bb.needGold = true
    bb.bestTargetInRange = function()
        return nil
    end
    mode = selector.decide(2)
    assert(mode == "farm" or mode == "roam", "expected farm or roam when safe and need gold")
    bb.bestTargetInRange = original

    return true
end
