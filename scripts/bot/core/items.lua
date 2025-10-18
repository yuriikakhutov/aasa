local UZ = require("scripts.bot.vendors.uczone_adapter")

---@class Items
local Items = {}

local function shouldUse(item, snapshot, plan)
    if item.cd and item.cd > 0 then
        return false
    end
    if plan.mode == "retreat" and item.name == "item_force_staff" then
        return true
    end
    if plan.mode == "engage" and plan.target and item.behavior ~= "passive" then
        return true
    end
    return false
end

---@param blackboard table
function Items.execute(blackboard)
    local plan = blackboard.tacticalPlan
    local snapshot = blackboard.sensors
    if not plan or not snapshot then
        return
    end

    local items = UZ.items()
    for _, item in ipairs(items) do
        if shouldUse(item, snapshot, plan) then
            local target = nil
            if item.behavior == "target" then
                target = plan.target
            elseif item.behavior == "point" and plan.target and plan.target.pos then
                target = plan.target.pos
            end

            local hash = item.name .. tostring(target and target.id or "")
            local last = blackboard.lastOrders.cast
            local now = os.clock()
            if not last or last.hash ~= hash or (now - last.time) > 0.2 then
                local ok, result = pcall(UZ.useItem, item.name, target)
                if ok and result then
                    blackboard.lastOrders.cast = {time = now, hash = hash}
                    break
                end
            end
        end
    end
end

return Items
