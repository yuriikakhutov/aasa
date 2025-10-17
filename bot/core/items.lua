local api = require("integration.uc_api")
local bb = require("core.blackboard")
local util = require("core.util")

local bit = bit32 or bit

local offensive_item_names = {
    item_orchid = true,
    item_bloodthorn = true,
    item_dagon = true,
    item_ethereal_blade = true,
    item_nullifier = true,
    item_shivas_guard = true,
    item_glimmer_cape = false,
    item_rod_of_atos = true,
}

local function has_behavior(behavior, flag)
    if not behavior or not flag then
        return false
    end
    if bit then
        return bit.band(behavior, flag) ~= 0
    end
    return false
end

local function is_ready(item)
    if not item or not item.handle then
        return false
    end
    if Ability.IsHidden and Ability.IsHidden(item.handle) then
        return false
    end
    if not Ability.IsReady(item.handle) then
        return false
    end
    if not Ability.IsOwnersManaEnough(item.handle) then
        return false
    end
    return true
end

local function is_offensive(name, data)
    if offensive_item_names[name] then
        return true
    end
    local behavior = data.behavior or 0
    return has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
        or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT)
        or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET)
end

local M = {}

function M.cast_item(item, target)
    if not item then
        return false
    end
    local handle = item.handle or item
    return api.cast(handle, target)
end

function M.offensive_items()
    local result = {}
    if not bb.heroData or not bb.heroData.items then
        return result
    end
    for name, data in pairs(bb.heroData.items) do
        if is_ready(data) and is_offensive(name, data) then
            table.insert(result, data.handle)
        end
    end
    return result
end

return M
