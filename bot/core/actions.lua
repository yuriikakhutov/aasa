local behaviors = require("ai.behaviors")
local tactics = require("ai.tactics")
local movement = require("core.movement")
local combat = require("core.combat")
local items = require("core.items")
local bb = require("core.blackboard")
local api = require("integration.uc_api")
local nav = require("core.nav")
local economy = require("core.economy")
local objective = require("core.objective")
local laning = require("core.laning")
local log = require("integration.log")

local M = {}

local function use_heal()
    if not bb.heroData or not bb.heroData.items then
        return
    end
    local priority = { "item_magic_wand", "item_magic_stick", "item_holy_locket", "item_mekansm", "item_guardian_greaves", "item_bloodstone" }
    for _, name in ipairs(priority) do
        local item = bb:getItem(name)
        if item and Ability.IsReady(item.handle or item) then
            items.cast_item(item, api.self())
            return
        end
    end
end

local handlers = {}

handlers.retreat = function(intent)
    use_heal()
    movement.safe_retreat()
end

handlers.fight = function(intent)
    local target = intent and intent.target or tactics.select_fight_target()
    if intent and intent.priorityTarget then
        target = intent.priorityTarget
    end
    if not target then
        return
    end
    if intent and intent.commit then
        combat.execute(target)
    else
        combat.harass(target)
    end
end

handlers.gank = function(intent)
    local target = intent and intent.target or tactics.select_gank_target()
    if target then
        combat.execute(target)
    end
end

handlers.push = function(intent)
    objective.pushLane(intent and intent.lane)
end

handlers.defend = function(intent)
    if not objective.defendTower() and intent and intent.position then
        movement.move_to(intent.position)
    end
end

handlers.farm = function(intent)
    local target = intent and intent.target or tactics.farm_target()
    if target then
        combat.finishSecure(target)
        api.attack(target)
    else
        movement.farmRoute()
    end
end

handlers.roam = function(intent)
    if intent and intent.position then
        movement.move_to(intent.position)
    else
        movement.roam()
    end
end

handlers.stack = function(intent)
    local data = intent and intent.data or laning.stackOpportunity(api.time())
    if data and data.approach then
        movement.move_to(data.approach)
    else
        movement.move_to(nav.nextRoamPoint())
    end
end

handlers.pull = function(intent)
    local data = intent and intent.data or laning.pullOpportunity(api.time())
    if data and data.approach then
        movement.move_to(data.approach)
    else
        movement.move_to(nav.nextRoamPoint())
    end
end

handlers.rune = function(intent)
    local spot = intent and intent.spot
    if not spot then
        spot = select(1, laning.runeWindow(api.time()))
    end
    if spot then
        movement.move_to(spot)
    end
end

handlers.shop = function(intent)
    economy.tick(api.time())
    local shopPos = nav.nearestShopPos()
    movement.move_to(shopPos or nav.nextRoamPoint())
end

handlers.heal = function(intent)
    use_heal()
    movement.safe_retreat()
end

handlers.objective = function(intent)
    if intent and intent.objective == "roshan" then
        objective.roshan()
    else
        if not objective.pushLane(intent and intent.lane) then
            objective.defendTower()
        end
    end
end

handlers.stackpull = function(intent)
    handlers.stack(intent)
    handlers.pull(intent)
end

local function run_handler(mode, intent)
    local handler = handlers[intent and intent.kind or mode]
    if handler then
        handler(intent)
    end
end

function M.execute(mode)
    laning.prepareRotation(api.time())
    local behavior = behaviors[mode]
    if not behavior then
        return
    end
    local intent = behavior()
    if not intent then
        return
    end
    run_handler(mode, intent)
end

return M
