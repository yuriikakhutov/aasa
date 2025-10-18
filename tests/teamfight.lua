local Blackboard = require('scripts.bot.core.blackboard')
local Tactics = require('scripts.bot.core.tactics')
local Micro = require('scripts.bot.core.micro')

local bb = Blackboard.new()

bb.sensors = {
    valid = true,
    time = 1000,
    team = 'radiant',
    self = { health = 1800, maxHealth = 2200, mana = 800, attackRange = 600 },
    enemies = {
        { name = 'npc_dota_hero_lion', level = 18, pos = { x = 100, y = 100 }, health = 900, maxHealth = 1200 },
        { name = 'npc_dota_hero_sven', level = 20, pos = { x = 180, y = 120 }, health = 2000, maxHealth = 2500, isCore = true },
        { name = 'npc_dota_hero_crystal_maiden', level = 16, pos = { x = 200, y = 150 }, health = 1100, maxHealth = 1100 },
    },
}

bb.path = { waypoints = { { x = 90, y = 90 }, { x = 120, y = 120 } } }

bb.tactics = Tactics.plan(bb)
assert(bb.tactics.mode ~= 'idle')

local orders = Micro.execute(bb)
assert(orders.attackTarget ~= nil)

print('[TEAMFIGHT] Tactical planning produced attack target')
