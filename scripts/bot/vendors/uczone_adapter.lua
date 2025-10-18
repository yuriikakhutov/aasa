local Log = require("scripts.bot.core.log")

local UZ = {}

local api = _G.UCZone or _G.Umbrella or {}

local function safeCall(name, ...)
    local fn = api[name]
    if type(fn) ~= "function" then
        Log.warn("UCZone API missing function: " .. name)
        return nil
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        Log.error("UCZone call failed: " .. name .. " - " .. tostring(result))
        return nil
    end
    return result
end

function UZ.self()
    return safeCall("GetSelf")
end

function UZ.time()
    return safeCall("GetGameTime") or os.clock()
end

function UZ.team()
    return safeCall("GetTeamName") or "radiant"
end

function UZ.enemyHeroes(radius)
    return safeCall("FindEnemyHeroes", radius) or {}
end

function UZ.allyHeroes(radius)
    return safeCall("FindAllyHeroes", radius) or {}
end

function UZ.enemyCreeps(radius)
    return safeCall("FindEnemyCreeps", radius) or {}
end

function UZ.allyCreeps(radius)
    return safeCall("FindAllyCreeps", radius) or {}
end

function UZ.neutrals(radius)
    return safeCall("FindNeutralCreeps", radius) or {}
end

function UZ.towers(team)
    return safeCall("FindTowers", team) or {}
end

function UZ.roshan()
    return safeCall("GetRoshan")
end

function UZ.runes()
    return safeCall("GetRunes") or {}
end

function UZ.move(pos)
    return safeCall("IssueMove", pos) or false
end

function UZ.attack(target)
    return safeCall("IssueAttack", target) or false
end

function UZ.attackMove(pos)
    return safeCall("IssueAttackMove", pos) or false
end

function UZ.stop()
    return safeCall("IssueStop") or false
end

function UZ.hold()
    return safeCall("IssueHold") or false
end

function UZ.cast(ability, param)
    return safeCall("CastAbility", ability, param) or false
end

function UZ.useItem(itemName, param)
    return safeCall("UseItem", itemName, param) or false
end

function UZ.blinkTo(pos)
    return safeCall("BlinkTo", pos) or false
end

function UZ.abilities()
    return safeCall("GetAbilities") or {}
end

function UZ.items()
    return safeCall("GetItems") or {}
end

function UZ.hasAghanim()
    return safeCall("HasAghanim") or false
end

function UZ.navMeshPath(fromPos, toPos)
    return safeCall("FindPath", fromPos, toPos) or {}
end

function UZ.isWalkable(pos)
    local result = safeCall("IsWalkable", pos)
    if result == nil then
        return true
    end
    return result
end

function UZ.distance(a, b)
    local fn = api.Distance or function(pa, pb)
        local dx = (pa.x or 0) - (pb.x or 0)
        local dy = (pa.y or 0) - (pb.y or 0)
        return math.sqrt(dx * dx + dy * dy)
    end
    local ok, res = pcall(fn, a, b)
    if ok then
        return res
    end
    return 0
end

function UZ.myPos()
    return safeCall("GetSelfPosition") or {x = 0, y = 0}
end

function UZ.fountainPos(team)
    return safeCall("GetFountainPosition", team) or {x = 0, y = 0}
end

function UZ.safeRetreatPoint()
    return safeCall("GetSafeRetreat") or UZ.fountainPos(UZ.team())
end

function UZ.ping(pos, msg)
    safeCall("PingMinimap", pos, msg)
end

function UZ.sayAllies(msg)
    safeCall("SayTeam", msg)
end

return UZ
