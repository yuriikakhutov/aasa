local Blackboard = require("scripts.bot.core.blackboard")
local Sensors = require("scripts.bot.core.sensors")
local Memory = require("scripts.bot.core.memory")
local DangerMap = require("scripts.bot.core.dangermap")
local Macro = require("scripts.bot.core.macro")
local Pathing = require("scripts.bot.core.pathing")
local Tactics = require("scripts.bot.core.tactics")
local Micro = require("scripts.bot.core.micro")
local Abilities = require("scripts.bot.core.abilities")
local Items = require("scripts.bot.core.items")
local Log = require("scripts.bot.core.log")
local UZ = require("scripts.bot.vendors.uczone_adapter")
local HeroCommon = require("scripts.bot.heroes._common")
local Rubick = require("scripts.bot.heroes.rubick")

local blackboard = Blackboard.new()
local memory = Memory.new()
local danger = DangerMap.new()
blackboard.memory = memory
blackboard.danger = danger

local TICK_HIGH = 0.15
local TICK_COMBAT = 0.04

local lastHigh = 0
local lastCombat = 0

local heroConfigurator = HeroCommon

local function initHero()
    local selfUnit = UZ.self()
    if not selfUnit or not selfUnit.name then
        return
    end

    if selfUnit.name == "npc_dota_hero_rubick" then
        heroConfigurator = Rubick
    end

    heroConfigurator.configure(blackboard)
end

local function highTick(now)
    local snapshot = Sensors.capture()
    if not snapshot then
        return
    end
    blackboard.sensors = snapshot
    memory:update(snapshot)
    danger:update(snapshot)
    Macro.evaluate(blackboard, memory)
    if blackboard.objective then
        Pathing.plan(blackboard, blackboard.objective)
    end
    if heroConfigurator.update then
        heroConfigurator.update(blackboard)
    end
end

local function combatTick(now)
    Tactics.plan(blackboard)
    Abilities.execute(blackboard)
    Items.execute(blackboard)
    Micro.execute(blackboard)
end

function Think()
    local now = UZ.time()
    if lastHigh == 0 then
        initHero()
        lastHigh = now
        lastCombat = now
    end

    if now - lastHigh >= TICK_HIGH then
        highTick(now)
        lastHigh = now
    end

    if now - lastCombat >= TICK_COMBAT then
        combatTick(now)
        lastCombat = now
    end
end

return {
    Think = Think
}
