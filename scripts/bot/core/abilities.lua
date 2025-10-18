local UZ = require("scripts.bot.vendors.uczone_adapter")
local Log = require("scripts.bot.core.log")

---@class Abilities
local Abilities = {}

local function canCast(ability, target)
    if ability.cd and ability.cd > 0 then
        return false
    end
    if ability.mana and ability.mana > (target.selfMana or 0) then
        return false
    end
    return true
end

---@param blackboard table
function Abilities.execute(blackboard)
    local plan = blackboard.tacticalPlan
    if not plan or plan.mode ~= "engage" or not plan.target then
        return
    end

    local snapshot = blackboard.sensors
    local selfUnit = snapshot and snapshot.selfUnit
    if not selfUnit then
        return
    end

    local abilities = UZ.abilities()
    for _, ability in ipairs(abilities) do
        if ability.behavior ~= "passive" and canCast(ability, {selfMana = selfUnit.mana or 0}) then
            local hash = ability.name .. (plan.target.id or "")
            local now = os.clock()
            local last = blackboard.lastOrders.cast
            if not last or last.hash ~= hash or (now - last.time) > 0.2 then
                local ok, result = pcall(UZ.cast, ability, plan.target)
                if ok and result then
                    blackboard.lastOrders.cast = {time = now, hash = hash}
                    break
                elseif not ok then
                    Log.error("Ability cast failed: " .. tostring(result))
                end
            end
        end
    end
end

return Abilities
