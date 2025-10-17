local api = require("integration.uc_api")
local bb = require("core.blackboard")
local skills = require("core.skills")
local items = require("core.items")
local movement = require("core.movement")
local util = require("core.util")
local log = require("integration.log")

local M = {
    _lastBurst = 0,
}

local function use_items(target)
    local itemData = bb.heroData and bb.heroData.items or {}
    for name, data in pairs(itemData or {}) do
        if data and data.handle and Ability.IsReady(data.handle) then
            local behavior = Ability.GetBehavior and Ability.GetBehavior(data.handle) or 0
            if name == "item_black_king_bar" then
                if bb.threat > 0.6 then
                    api.cast(data.handle, nil)
                end
            elseif name == "item_satanic" and bb.hpRatio < 0.4 then
                api.cast(data.handle, nil)
            elseif name == "item_shivas_guard" then
                api.cast(data.handle, nil)
            elseif name == "item_orchid" or name == "item_bloodthorn" or name == "item_sheepstick" then
                api.cast(data.handle, target)
            elseif name == "item_force_staff" and bb:isUnderThreat() then
                api.cast(data.handle, api.self())
            end
        end
    end
end

function M.prepareBurst()
    local targetData = bb:bestEnemy()
    if not targetData then
        return nil
    end
    return targetData.entity
end

local function should_all_in(target)
    if not target then
        return false
    end
    local hp = Entity.GetHealth(target)
    local projected = (bb.heroData.comboDamage or 0) + (bb.heroData.attackDamage or 0) * 3
    return projected >= hp * 0.9
end

function M.avoidDanger()
    local hero = api.self()
    if not hero then
        return
    end
    local incoming = api.projectDamage(hero, 2)
    if incoming > Entity.GetHealth(hero) * 0.8 then
        movement.safe_retreat()
    end
end

function M.burstCombo(target)
    if not target then
        return false
    end
    use_items(target)
    skills.burstCombo(target)
    if should_all_in(target) then
        movement.chaseAggressive(target)
    else
        movement.kite(target)
    end
    M._lastBurst = api.time()
    return true
end

function M.finishSecure(target)
    return skills.finishSecure(target)
end

function M.execute(target)
    if not target then
        target = M.prepareBurst()
    end
    if not target then
        return
    end
    M.avoidDanger()
    if bb:isUnderThreat() and not should_all_in(target) then
        movement.safe_retreat()
        return
    end
    if not M.finishSecure(target) then
        M.burstCombo(target)
    end
end

function M.harass(target)
    if not target then
        target = M.prepareBurst()
    end
    if not target then
        return
    end
    local spells = skills.poke_spells(target)
    for _, ability in ipairs(spells) do
        api.cast(ability, target)
    end
    movement.kite(target)
end

return M
