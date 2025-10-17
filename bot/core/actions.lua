local movement = require("core.movement")
local combat = require("core.combat")
local util = require("core.util")
local bb = require("core.blackboard")
local api = require("integration.uc_api")
local nav = require("core.nav")
local navLow = require("integration.nav")
local log = require("integration.log")

local M = {}

local function hero_position()
    local hero = api.self()
    if not hero or not Entity.GetAbsOrigin then
        return nil, hero
    end
    return Entity.GetAbsOrigin(hero), hero
end

local function nearest_entry(entries, reference)
    if not entries or #entries == 0 or not reference then
        return nil
    end
    local best, bestDist
    for _, entry in ipairs(entries) do
        local entity = entry.entity or entry
        if entity and api.isAlive(entity) then
            local pos = entry.position
            if not pos and Entity.GetAbsOrigin then
                pos = Entity.GetAbsOrigin(entity)
            end
            if pos then
                local dist = util.distance2d(reference, pos)
                if not bestDist or dist < bestDist then
                    best = entry
                    bestDist = dist
                end
            end
        end
    end
    return best
end

local function handle_fight(state)
    local pos, hero = hero_position()
    if not hero then
        return
    end
    local targetInfo = nearest_entry(state.visibleEnemies, pos)
    local target = targetInfo and (targetInfo.entity or targetInfo)
    if not target then
        movement.roam(api.time(), state)
        return
    end
    log.info("Combat: engaging enemy target")
    combat.execute(target)
    movement.chaseAggressive(target)
end

local function handle_farm(state)
    local pos, hero = hero_position()
    if not hero then
        return
    end
    local creepInfo = nearest_entry(state.visibleCreeps, pos)
    local creep = creepInfo and (creepInfo.entity or creepInfo)
    if not creep then
        movement.roam(api.time(), state)
        return
    end
    log.info("Farm: attacking nearest creep")
    if combat.finishSecure then
        combat.finishSecure(creep)
    end
    movement.attack(creep)
end

local function handle_roam(state)
    movement.roam(api.time(), state)
end

local function handle_retreat(state)
    local _, hero = hero_position()
    if not hero then
        return
    end
    local team = Entity.GetTeamNum(hero)
    local fountain = navLow.get_fountain(team)
    if fountain then
        movement.move_to(fountain)
    else
        local safe = nav.safeRetreat()
        if safe then
            movement.move_to(safe)
        end
    end
end

function M.execute(now, board)
    local state = board or bb
    state.mode = state.mode or "roam"

    if state.mode == "fight" then
        handle_fight(state)
        return
    end
    if state.mode == "farm" then
        handle_farm(state)
        return
    end
    if state.mode == "retreat" then
        handle_retreat(state)
        return
    end
    handle_roam(state)
end

return M
