---
-- Item usage handler for active items with safety checks.
---

local Log = require("scripts.bot.core.log")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Items = {}

local function isReady(item, selfUnit)
    if not item then
        return false
    end
    if item.cd and item.cd > 0.1 then
        return false
    end
    if item.mana and selfUnit and selfUnit.mana and item.mana > selfUnit.mana then
        return false
    end
    return true
end

local function use(item, payload)
    local ok, result = pcall(UZ.useItem, item.name, payload)
    if not ok then
        Log.error("Failed to use item " .. tostring(item.name) .. ": " .. tostring(result))
        return false
    end
    return result
end

function Items.execute(bb, orders)
    local sensors = bb.sensors or {}
    local items = sensors.items or {}
    local tactics = bb.tactics or {}

    for _, item in ipairs(items) do
        if not item.isPassive and isReady(item, sensors.self) then
            local payload
            if item.behavior == "UNIT_TARGET" then
                payload = tactics.focus or orders.attackTarget
            elseif item.behavior == "POINT" then
                payload = (tactics.focus and tactics.focus.pos) or orders.move
            end
            if use(item, payload) then
                return true
            end
        end
    end
    return false
end

return Items
