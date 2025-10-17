local selector = require("core.selector")
local bb = require("core.blackboard")
local laning = require("core.laning")
local objective = require("core.objective")
local api = require("integration.uc_api")

return function()
    bb:reset()
    bb.safe = false
    bb.hpRatio = 0.2
    bb.threat = 1.1
    local mode = selector.decide(0)
    assert(mode == "retreat", "expected retreat when under threat")

    bb.safe = true
    bb.hpRatio = 0.9
    bb.threat = 0.1
    bb.winChance = 0.7
    local originalBest = bb.bestTargetInRange
    function bb:bestTargetInRange()
        return {}
    end
    mode = selector.decide(1)
    assert(mode == "fight", "expected fight when winning")

    local originalRune = laning.runeWindow
    laning.runeWindow = function()
        return Vector(0, 0, 0), 120
    end
    mode = selector.decide(119)
    assert(mode == "rune", "expected rune priority before spawn")
    laning.runeWindow = originalRune

    local originalStack = laning.stackOpportunity
    laning.stackOpportunity = function()
        return { pullTime = 53 }
    end
    bb.safe = true
    bb.threat = 0.1
    bb.needGold = false
    function bb:bestTargetInRange()
        return nil
    end
    mode = selector.decide(10)
    assert(mode == "stack", "expected stack mode when opportunity is present")
    bb.bestTargetInRange = originalBest
    laning.stackOpportunity = originalStack

    return true
end
