local UZ = require("scripts.bot.vendors.uczone_adapter")

---@class Tactics
local Tactics = {}

---@param blackboard table
function Tactics.plan(blackboard)
    local snapshot = blackboard.sensors
    if not snapshot then
        return
    end

    local plan = {
        target = nil,
        mode = "idle"
    }

    local enemies = snapshot.enemies or {}
    if #enemies > 0 then
        table.sort(enemies, function(a, b)
            local ahp = a.health or 1
            local bhp = b.health or 1
            return ahp < bhp
        end)
        plan.target = enemies[1]
        plan.mode = "engage"
    elseif blackboard.objective and blackboard.objective.type == "retreat" then
        plan.mode = "retreat"
    else
        plan.mode = "move"
    end

    blackboard.tacticalPlan = plan
end

return Tactics
