local util = require("core.util")
local api = require("integration.uc_api")

local M = {
    _fountainPositions = {},
    _roamIndex = 1,
    _roamPoints = {
        Vector(-4100, -4100, 0),
        Vector(-3600, 2800, 0),
        Vector(4000, 3800, 0),
        Vector(3200, -3600, 0),
        Vector(0, 0, 0),
        Vector(-1700, 1200, 0),
        Vector(1700, -1200, 0),
    },
}

local function detect_fountains()
    if next(M._fountainPositions) then
        return
    end
    if not NPCs or not NPCs.GetAll then
        return
    end
    for _, npc in ipairs(NPCs.GetAll()) do
        if npc and Entity.GetUnitName then
            local name = Entity.GetUnitName(npc)
            if name and string.find(name, "fountain") then
                local team = Entity.GetTeamNum(npc)
                M._fountainPositions[team] = Entity.GetAbsOrigin(npc)
            end
        end
    end
end

function M.get_fountain(team)
    detect_fountains()
    return M._fountainPositions[team]
end

function M.find_path(startPos, endPos)
    if not startPos or not endPos or not GridNav or not GridNav.BuildPath then
        return { endPos }
    end
    local hero = api.self()
    local npcMap = nil
    if GridNav.CreateNpcMap then
        npcMap = GridNav.CreateNpcMap({ hero }, true)
    end
    local path = GridNav.BuildPath(startPos, endPos, false, npcMap)
    if npcMap and GridNav.ReleaseNpcMap then
        GridNav.ReleaseNpcMap(npcMap)
    end
    if not path or #path == 0 then
        return { endPos }
    end
    return path
end

function M.is_traversable(pos)
    if not GridNav or not GridNav.IsTraversable then
        return true
    end
    local traversable = GridNav.IsTraversable(pos)
    return traversable == true
end

function M.get_safe_back_pos()
    local hero = api.self()
    if not hero then
        return nil
    end
    local heroPos = Entity.GetAbsOrigin(hero)
    local team = Entity.GetTeamNum(hero)
    local fountain = M.get_fountain(team)
    if fountain then
        local direction = util.normalize(fountain - heroPos)
        return heroPos + direction * 600
    end
    return heroPos + Vector(0, 0, 0)
end

function M.next_roam_point()
    local point = M._roamPoints[M._roamIndex]
    M._roamIndex = M._roamIndex + 1
    if M._roamIndex > #M._roamPoints then
        M._roamIndex = 1
    end
    return point
end

function M.advance_position(current, direction, distance)
    return current + util.normalize(direction) * distance
end

function M.escape_vector(heroPos, threats)
    local escape = Vector(0, 0, 0)
    for _, enemy in ipairs(threats or {}) do
        local dir = util.normalize(heroPos - enemy.position)
        escape = escape + dir * (enemy.threat or 1)
    end
    if escape.Length2D then
        if escape:Length2D() < 0.1 then
            return heroPos + Vector(0, 0, 0)
        end
        return heroPos + escape:Normalized() * 600
    end
    return heroPos + util.normalize(escape) * 600
end

return M
