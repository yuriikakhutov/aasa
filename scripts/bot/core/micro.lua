local UZ = require("scripts.bot.vendors.uczone_adapter")

---@class Micro
local Micro = {}

local function coalesce(blackboard, orderType, hash, fn)
    local entry = blackboard.lastOrders[orderType]
    local now = os.clock()
    if entry and (now - entry.time) < 0.12 and entry.hash == hash then
        return false
    end

    local ok, result = pcall(fn)
    if not ok then
        return false
    end

    blackboard.lastOrders[orderType] = {time = now, hash = hash}
    return result
end

---@param blackboard table
function Micro.execute(blackboard)
    local plan = blackboard.tacticalPlan
    local snapshot = blackboard.sensors
    if not plan or not snapshot then
        return
    end

    if plan.mode == "engage" and plan.target then
        local target = plan.target
        coalesce(blackboard, "attack", target.id or target.handle, function()
            return UZ.attack(target)
        end)
    elseif plan.mode == "retreat" then
        local point = UZ.safeRetreatPoint()
        coalesce(blackboard, "move", "retreat" .. tostring(point.x or 0), function()
            return UZ.move(point)
        end)
    elseif blackboard.objective and blackboard.objective.position then
        local waypoint = require("scripts.bot.core.pathing").advance(blackboard)
        if waypoint then
            coalesce(blackboard, "move", string.format("%d:%d", waypoint.x or 0, waypoint.y or 0), function()
                return UZ.move(waypoint)
            end)
        end
    end
end

return Micro
