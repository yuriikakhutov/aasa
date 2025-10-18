---
-- Main entry point wiring all subsystems together.
---

local Log = require("scripts.bot.core.logger")
local Blackboard = require("scripts.bot.core.blackboard")
local Sensors = require("scripts.bot.core.sensors")
local Memory = require("scripts.bot.core.memory")
local ProbPos = require("scripts.bot.core.probpos")
local DangerMap = require("scripts.bot.core.dangermap")
local Macro = require("scripts.bot.core.macro")
local Pathing = require("scripts.bot.core.pathing")
local Tactics = require("scripts.bot.core.tactics")
local Micro = require("scripts.bot.core.micro")
local Abilities = require("scripts.bot.core.abilities")
local Items = require("scripts.bot.core.items")
local Economy = require("scripts.bot.core.economy")
local Team = require("scripts.bot.core.team")
local OrderCoalescer = require("scripts.bot.core.order_coalescer")
local AntiStuck = require("scripts.bot.core.anti_stuck")
local Profiler = require("scripts.bot.core.profiler")
local Validators = require("scripts.bot.core.validators")
local UZ = require("scripts.bot.vendors.uczone_adapter")

local Bot = {}

local state = {
    bb = Blackboard.new(),
    memory = Memory.new(),
    probpos = ProbPos.new(),
    danger = DangerMap.new(),
    lastHighTick = -math.huge,
    lastCombatTick = -math.huge,
    heroInitialised = false,
    coalescer = OrderCoalescer.new(),
    antiStuck = AntiStuck.new(),
    profiler = Profiler.new(),
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

local function queueMovementOrders(orders)
    if orders.stopAttacking then
        state.coalescer:queue("move", "stop", UZ.stop)
        return
    end
    if orders.attackTarget then
        local signature = tostring(orders.attackTarget.id or orders.attackTarget.handle or orders.attackTarget.name)
        state.coalescer:queue("attack", signature, UZ.attack, orders.attackTarget)
    end
    if orders.move then
        local pos = orders.move
        local signature = string.format("%.1f:%.1f", pos.x or 0, pos.y or 0)
        state.coalescer:queue("move", signature, UZ.move, pos)
    end
end

local function highTick(now)
    local tickStart = os.clock()
    state.bb.sensors = Sensors.capture()
    if not state.bb.sensors.valid then
        return
    end
    ensureHeroModule()

    state.memory:updateFromSensors(state.bb.sensors)
    state.bb.memory = state.memory

    local estimates = state.probpos:update(state.memory, state.bb.sensors)
    state.bb.probpos = estimates

    state.danger:decay()
    state.danger:ingest(state.bb.sensors, state.memory)
    state.bb.danger = state.danger

    state.bb.macro = Macro.plan(state.bb)
    Pathing.plan(state.bb)
    Economy.decide(state.bb)

    state.bb.teamRole = state.bb.teamRole or Team.assignRole(state.bb.sensors)
    state.antiStuck:record(state.bb.sensors.time or now, state.bb.sensors.pos)
    state.bb.antiStuck.isStuck = state.antiStuck:isStuck()

    Validators.assert_timer_granularity(state.bb.settings)
    local duration = os.clock() - tickStart
    state.profiler:recordTick("high", duration)
end

local function combatTick(now)
    if not state.bb.sensors or not state.bb.sensors.valid then
        return
    end
    local tickStart = os.clock()

    state.bb.tactics = Tactics.plan(state.bb)
    local orders = Micro.execute(state.bb)
    state.bb.micro = orders

    if state.bb.heroModule and state.bb.heroModule.beforeAbility then
        state.bb.heroModule.beforeAbility(state.bb)
    end

    local abilityQueued = Abilities.execute(state.bb, state.coalescer, UZ)
    if not abilityQueued then
        Items.execute(state.bb, state.coalescer, UZ)
    end

    queueMovementOrders(orders)

    local issued = state.coalescer:flush()
    state.bb:appendOrderHistory(issued)
    state.profiler:recordOrders(issued)
    state.profiler:recordTick("combat", os.clock() - tickStart)
    state.profiler:flushIfNeeded()

    state.bb.orders = state.coalescer.lastIssued
    Validators.assert_no_spam_orders(state.bb.orderHistory)
end

function Bot.Init()
    Log.info("UCZone bot initialised")
    Validators.assert_no_globals()
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
