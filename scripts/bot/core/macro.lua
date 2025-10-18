local Utility = require("scripts.bot.core.utility")
local Objectives = require("scripts.bot.core.objectives")

---@class Macro
local Macro = {}

---@param blackboard table
---@param memory table
function Macro.evaluate(blackboard, memory)
    local snapshot = blackboard.sensors
    if not snapshot then
        return
    end

    local weights = Utility.score(snapshot, memory)
    local best, bestScore
    for name, score in pairs(weights) do
        if not best or score > bestScore then
            best = name
            bestScore = score
        end
    end

    if not best then
        return
    end

    blackboard.objective = Objectives.build(best, snapshot, memory)
end

return Macro
