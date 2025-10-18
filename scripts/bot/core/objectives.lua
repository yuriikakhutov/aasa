local UZ = require("scripts.bot.vendors.uczone_adapter")

---@class Objectives
local Objectives = {}

local BUILDER = {}

function BUILDER.farm(snapshot)
    local creeps = snapshot.neutrals or {}
    local target = creeps[1]
    return {
        type = "farm",
        position = target and target.pos or UZ.safeRetreatPoint()
    }
end

function BUILDER.push(snapshot)
    return {
        type = "push",
        position = snapshot.objectivePos or UZ.safeRetreatPoint()
    }
end

function BUILDER.defend(snapshot)
    local fountain = UZ.fountainPos(UZ.team())
    return {
        type = "defend",
        position = fountain
    }
end

function BUILDER.gank(snapshot)
    local enemy = (snapshot.enemies or {})[1]
    if enemy and enemy.pos then
        return {type = "gank", position = enemy.pos}
    end
    return BUILDER.farm(snapshot)
end

function BUILDER.rune(snapshot)
    local rune = snapshot.runes and snapshot.runes[1]
    if rune then
        return {type = "rune", position = rune.pos, rune = rune}
    end
    return BUILDER.farm(snapshot)
end

function BUILDER.roshan(snapshot)
    local roshan = UZ.roshan()
    return {
        type = "roshan",
        position = roshan and roshan.pos or UZ.safeRetreatPoint()
    }
end

function BUILDER.retreat(snapshot)
    return {
        type = "retreat",
        position = UZ.safeRetreatPoint()
    }
end

function BUILDER.regroup(snapshot)
    return {
        type = "regroup",
        position = UZ.safeRetreatPoint()
    }
end

---@param name string
---@param snapshot table
---@return table
function Objectives.build(name, snapshot)
    local builder = BUILDER[name]
    if builder then
        return builder(snapshot)
    end
    return BUILDER.farm(snapshot)
end

return Objectives
