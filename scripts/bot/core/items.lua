---
-- Item usage handler for active items with safety checks routed through the
-- order coalescer.
---

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
    if item.isPassive then
        return false
    end
    return true
end

local function itemSignature(item)
    return tostring(item.name or item.id)
end

local function determinePayload(item, tactics, orders)
    if item.behavior == "UNIT_TARGET" then
        return tactics.focus or orders.attackTarget
    elseif item.behavior == "POINT" then
        local focus = tactics.focus or orders.attackTarget
        return (focus and focus.pos) or orders.move
    end
    return nil
end

function Items.execute(bb, coalescer, UZ)
    local sensors = bb.sensors or {}
    local items = sensors.items or {}
    local tactics = bb.tactics or {}
    local issued = false

    for _, item in ipairs(items) do
        if isReady(item, sensors.self) then
            local payload = determinePayload(item, tactics, bb.micro or {})
            if coalescer:queue("item", itemSignature(item), UZ.useItem, item.name, payload) then
                issued = true
                break
            end
        end
    end

    return issued
end

return Items
