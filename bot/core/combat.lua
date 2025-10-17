local api = require("integration.uc_api")
local bb = require("core.blackboard")
local skills = require("core.skills")
local items = require("core.items")
local movement = require("core.movement")
local util = require("core.util")

local M = {}

local function use_gap_closer(target)
    local blink = bb:getItem("item_blink") or bb:getItem("item_overwhelming_blink")
    if blink then
        local targetPos = Entity.GetAbsOrigin(target)
        local hero = api.self()
        if hero then
            local heroPos = Entity.GetAbsOrigin(hero)
            local direction = util.normalize(targetPos - heroPos)
            local blinkPos = heroPos + direction * math.min(util.distance2d(heroPos, targetPos) - 200, 1150)
            items.cast_item(blink, blinkPos)
        end
    end
end

local function use_defensive()
    local euls = bb:getItem("item_cyclone")
    if euls and bb:isLowResources() then
        items.cast_item(euls, api.self())
    end
    local greaves = bb:getItem("item_guardian_greaves")
    if greaves and bb:isLowResources() then
        items.cast_item(greaves, nil)
    end
end

function M.execute(target)
    if not target then
        return
    end
    local hero = api.self()
    if not hero then
        return
    end
    use_defensive()
    use_gap_closer(target)
    local abilityOrder = skills.prioritized_spells(target)
    for _, ability in ipairs(abilityOrder) do
        skills.cast(ability, target)
    end
    local offensiveItems = items.offensive_items()
    for _, item in ipairs(offensiveItems) do
        items.cast_item(item, target)
    end
    api.attack(target)
    movement.kite(target)
end

function M.harass(target)
    if not target then
        return
    end
    local hero = api.self()
    if not hero then
        return
    end
    local spells = skills.poke_spells(target)
    for _, ability in ipairs(spells) do
        skills.cast(ability, target)
    end
    api.attack(target)
end

return M
