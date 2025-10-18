local UZ = require("scripts.bot.vendors.uczone_adapter")
local Log = require("scripts.bot.core.log")

---@class Pathing
local Pathing = {}

---@param blackboard table
---@param objective table
function Pathing.plan(blackboard, objective)
    if not objective or not objective.position then
        blackboard.path = nil
        return
    end

    local startPos = UZ.myPos()
    local ok, path = pcall(UZ.navMeshPath, startPos, objective.position)
    if not ok or not path or #path == 0 then
        Log.warn("NavMesh path failed, using direct fallback")
        blackboard.path = {objective.position}
        return
    end

    local filtered = {}
    for _, point in ipairs(path) do
        if UZ.isWalkable(point) then
            table.insert(filtered, point)
        end
    end

    if #filtered == 0 then
        filtered = {objective.position}
    end

    blackboard.path = filtered
end

---@param blackboard table
function Pathing.advance(blackboard)
    local path = blackboard.path
    if not path or #path == 0 then
        return nil
    end

    local pos = UZ.myPos()
    local nextIdx = 1
    local target = path[nextIdx]
    if not target then
        return nil
    end

    if UZ.distance(pos, target) < 150 then
        table.remove(path, nextIdx)
        target = path[nextIdx]
    end

    return target
end

return Pathing
