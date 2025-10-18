---
-- UCZone adapter: centralises all interaction with the environment so the
-- bot can be easily retargeted if the API names differ. Each function tries
-- multiple method names to support both UCZone and Umbrella conventions.
---

local Log = require("scripts.bot.core.log")

local ok, backend = pcall(require, "UCZone")
if not ok then
    ok, backend = pcall(require, "uczone")
end
if not ok then
    ok, backend = pcall(require, "umbrella")
end
if not ok then
    backend = {}
end

local UZ = {}

local function callBackend(candidates, ...)
    for _, name in ipairs(candidates) do
        local fn = backend[name]
        if type(fn) == "function" then
            local okCall, result = pcall(fn, ...)
            if okCall then
                return result
            else
                Log.error("Backend call failed: " .. tostring(name) .. " -> " .. tostring(result))
                return nil
            end
        end
    end
    return nil
end

local function passthrough(name, ...)
    local fn = backend[name]
    if type(fn) ~= "function" then
        return nil
    end
    local okCall, result = pcall(fn, ...)
    if not okCall then
        Log.error("Backend call failed: " .. tostring(name) .. " -> " .. tostring(result))
        return nil
    end
    return result
end

-- Identification / objects
function UZ.self()
    return callBackend({ "GetSelf", "Self" })
end

function UZ.time()
    return callBackend({ "GetTime", "Time" }) or 0
end

function UZ.team()
    return callBackend({ "GetTeamName", "Team" }) or "radiant"
end

-- Unit queries
function UZ.enemyHeroes(radius)
    return callBackend({ "EnemyHeroes", "GetEnemyHeroes" }, radius) or {}
end

function UZ.allyHeroes(radius)
    return callBackend({ "AllyHeroes", "GetAllyHeroes" }, radius) or {}
end

function UZ.enemyCreeps(radius)
    return callBackend({ "EnemyCreeps", "GetEnemyCreeps" }, radius) or {}
end

function UZ.allyCreeps(radius)
    return callBackend({ "AllyCreeps", "GetAllyCreeps" }, radius) or {}
end

function UZ.neutrals(radius)
    return callBackend({ "NeutralCreeps", "GetNeutralCreeps" }, radius) or {}
end

function UZ.towers(team)
    return callBackend({ "Towers", "GetTowers" }, team) or {}
end

function UZ.roshan()
    return callBackend({ "Roshan", "GetRoshan" })
end

function UZ.runes()
    return callBackend({ "Runes", "GetRunes" }) or {}
end

-- Navigation / orders
function UZ.move(pos)
    return callBackend({ "OrderMove", "MoveTo" }, pos) or false
end

function UZ.attack(target)
    return callBackend({ "OrderAttack", "AttackTarget" }, target) or false
end

function UZ.attackMove(pos)
    return callBackend({ "OrderAttackMove", "AttackMove" }, pos) or false
end

function UZ.stop()
    return callBackend({ "OrderStop", "Stop" }) or false
end

function UZ.hold()
    return callBackend({ "OrderHold", "HoldPosition" }) or false
end

function UZ.cast(ability, target)
    return callBackend({ "CastAbility", "Cast" }, ability, target) or false
end

function UZ.useItem(itemName, target)
    return callBackend({ "UseItem", "Item" }, itemName, target) or false
end

function UZ.blinkTo(pos)
    return callBackend({ "Blink", "BlinkTo" }, pos) or false
end

-- Ability / item info
function UZ.abilities()
    return callBackend({ "Abilities", "GetAbilities" }) or {}
end

function UZ.items()
    return callBackend({ "Items", "GetItems" }) or {}
end

function UZ.hasAghanim()
    local value = callBackend({ "HasAghanim", "HasScepter" })
    return not not value
end

-- Geometry / pathing
function UZ.navMeshPath(fromPos, toPos)
    return callBackend({ "NavMeshPath", "FindPath" }, fromPos, toPos) or {}
end

function UZ.isWalkable(pos)
    local result = callBackend({ "IsWalkable", "Walkable" }, pos)
    return not not result
end

function UZ.distance(a, b)
    if backend.Distance then
        return passthrough("Distance", a, b)
    end
    if a and b then
        local dx = (a.x or 0) - (b.x or 0)
        local dy = (a.y or 0) - (b.y or 0)
        return math.sqrt(dx * dx + dy * dy)
    end
    return 0
end

function UZ.myPos()
    return callBackend({ "MyPosition", "GetPosition" }) or { x = 0, y = 0, z = 0 }
end

function UZ.fountainPos(team)
    return callBackend({ "FountainPosition", "GetFountain" }, team)
end

function UZ.safeRetreatPoint()
    return callBackend({ "SafeRetreat", "GetSafeRetreatPoint" })
end

-- Misc
function UZ.ping(pos, msg)
    return callBackend({ "Ping", "SendPing" }, pos, msg)
end

function UZ.sayAllies(msg)
    return callBackend({ "SayAllies", "TeamMessage" }, msg)
end

return UZ
