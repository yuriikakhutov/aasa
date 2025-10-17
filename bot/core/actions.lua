local behaviors = require("ai.behaviors")
local tactics = require("ai.tactics")
local movement = require("core.movement")
local combat = require("core.combat")
local items = require("core.items")
local bb = require("core.blackboard")
local api = require("integration.uc_api")

local M = {}

local function use_heal()
    if not bb.heroData or not bb.heroData.items then
        return
    end
    local priority = { "item_magic_wand", "item_magic_stick", "item_holy_locket", "item_mekansm", "item_guardian_greaves", "item_bloodstone" }
    for _, name in ipairs(priority) do
        local item = bb:getItem(name)
        if item and Ability.IsReady(item) then
            items.cast_item(item, api.self())
            return
        end
    end
end

local handlers = {}

handlers.retreat = function(intent)
    if intent.escape then
        items.cast_item(intent.escape, api.self())
    end
    movement.retreat()
end

handlers.fight = function(intent)
    local target = intent.target or tactics.select_fight_target()
    if not target then
        return
    end
    if intent.commit then
        combat.execute(target)
    else
        combat.harass(target)
    end
end

handlers.move = function(intent)
    if intent.position then
        movement.move_to(intent.position)
    end
end

handlers.farm = function(intent)
    local target = intent.target or tactics.farm_target()
    if target then
        api.attack(target)
    else
        handlers.move(behaviors.roam())
    end
end

handlers.heal = function(intent)
    use_heal()
    movement.retreat()
end

handlers.push = function(intent)
    if intent.position then
        movement.attack_move(intent.position)
    end
end

handlers.wait = function()
    movement.hold_position()
end

function M.execute(mode)
    local behavior = behaviors[mode]
    if not behavior then
        return
    end
    local intent = behavior()
    if not intent then
        return
    end
    local handler = handlers[intent.kind or mode]
    if handler then
        handler(intent)
    end
end

return M
