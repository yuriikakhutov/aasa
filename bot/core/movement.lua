local api = require("integration.uc_api")
local nav = require("integration.nav")
local util = require("core.util")
local M = {}

function M.move_to(position)
    if not position then
        return
    end
    api.move_to(position)
end

function M.attack_move(position)
    local hero = api.self()
    local player = api.player()
    if not hero or not player or not position then
        return
    end
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
        nil,
        position,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        hero,
        false,
        false,
        false,
        true,
        "attack_move"
    )
end

function M.kite(target)
    local hero = api.self()
    if not hero or not target then
        return
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local targetPos = Entity.GetAbsOrigin(target)
    local retreat = nav.escape_vector(heroPos, {
        {
            position = targetPos,
            threat = 1,
        }
    })
    api.move_to(retreat)
end

function M.retreat()
    local safePos = nav.get_safe_back_pos()
    if safePos then
        api.move_to(safePos)
    end
end

function M.follow_path(path)
    if not path then
        return
    end
    local hero = api.self()
    if not hero then
        return
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local closest = path[#path]
    local minDist = math.huge
    for _, node in ipairs(path) do
        local dist = util.distance2d(heroPos, node)
        if dist < minDist then
            minDist = dist
            closest = node
        end
    end
    api.move_to(closest)
end

function M.hold_position()
    local hero = api.self()
    local player = api.player()
    if not hero or not player then
        return
    end
    Player.HoldPosition(player, hero, false, false, true, "hold")
end

return M
