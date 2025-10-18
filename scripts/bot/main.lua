---
-- Main entry point wiring all subsystems together.
---

local Log = require("scripts.bot.core.log")
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
local Economy = require("scripts.bot.core.economy")
local Team = require("scripts.bot.core.team")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Bot = {}

local state = {
    bb = Blackboard.new(),
    memory = Memory.new(),
    danger = DangerMap.new(),
    lastHighTick = -math.huge,
    lastCombatTick = -math.huge,
    heroInitialised = false,
}

local function ensureHeroModule()
    if state.heroInitialised then
        return
    end
    local hero = state.bb.sensors and state.bb.sensors.self
    if not hero or not hero.name then
        return
    end
    local name = string.lower(hero.name)
    if string.find(name, "rubick") then
        local module = require("scripts.bot.heroes.rubick")
        module.init(state.bb)
        state.bb.heroModule = module
        Log.info("Rubick hero module initialised")
    end
    state.heroInitialised = true
end

local function canIssue(orderType, signature)
    local orders = state.bb.orders
    local now = os.clock()
    local record = orders[orderType]
    if record and now - (record.time or -math.huge) < state.bb.settings.orderCooldown then
        return false
    end
    if record and record.signature == signature and now - (record.time or -math.huge) < 0.6 then
        return false
    end
    return true
end

local function markIssued(orderType, signature)
    state.bb.orders[orderType] = {
        time = os.clock(),
        signature = signature,
    }
end

local function issueMove(pos)
    if not pos then
        return
    end
    local signature = string.format("%.1f:%.1f", pos.x or 0, pos.y or 0)
    if not canIssue("lastMove", signature) then
        return
    end
    local ok, result = pcall(UZ.move, pos)
    if ok and result then
        markIssued("lastMove", signature)
    end
end

local function issueAttack(target)
    if not target then
        return
    end
    local signature = tostring(target.id or target.handle or target.name)
    if not canIssue("lastAttack", signature) then
        return
    end
    local ok, result = pcall(UZ.attack, target)
    if ok and result then
        markIssued("lastAttack", signature)
    end
end

local function issueStop()
    if not canIssue("lastMove", "stop") then
        return
    end
    local ok, result = pcall(UZ.stop)
    if ok and result then
        markIssued("lastMove", "stop")
    end
end

local function highTick(now)
    state.bb.sensors = Sensors.capture()
    if not state.bb.sensors.valid then
        return
    end
    ensureHeroModule()

    state.memory:updateFromSensors(state.bb.sensors)
    state.bb.memory = state.memory

    state.danger:decay()
    state.danger:ingest(state.bb.sensors, state.memory)
    state.bb.danger = state.danger

    state.bb.macro = Macro.plan(state.bb)
    Pathing.plan(state.bb)
    Economy.decide(state.bb)

    state.bb.teamRole = state.bb.teamRole or Team.assignRole(state.bb.sensors)
end

local function combatTick(now)
    if not state.bb.sensors or not state.bb.sensors.valid then
        return
    end

    state.bb.tactics = Tactics.plan(state.bb)
    local orders = Micro.execute(state.bb)
    state.bb.micro = orders

    local casted = Abilities.execute(state.bb, orders)
    if not casted then
        Items.execute(state.bb, orders)
    end

    if orders.stopAttacking then
        issueStop()
        return
    end

    if orders.attackTarget then
        issueAttack(orders.attackTarget)
    end

    if orders.move then
        issueMove(orders.move)
    end
end

function Bot.Init()
    Log.info("UCZone bot initialised")
end

function Bot.Tick()
    local now = os.clock()
    if now - state.lastHighTick >= state.bb.settings.tickHigh then
        highTick(now)
        state.lastHighTick = now
    end
    if now - state.lastCombatTick >= state.bb.settings.tickCombat then
        combatTick(now)
        state.lastCombatTick = now
    end
end

return Bot
