local Blackboard = require('scripts.bot.core.blackboard')
local Utility = require('scripts.bot.core.utility')
local Macro = require('scripts.bot.core.macro')

local bb = Blackboard.new()

bb.sensors = {
    valid = true,
    time = 10,
    team = 'radiant',
    self = { health = 520, maxHealth = 700, networth = 2200, mana = 300 },
    allies = {
        { networth = 2000 },
        { networth = 2300 },
    },
    enemies = {},
    runes = {},
}

bb.memory = {
    runes = {},
}

local scores = Utility.evaluate(bb)
assert(scores.farm > 0)

bb.macro = Macro.plan(bb)
assert(bb.macro.kind ~= nil)

print('[LANING] Utility and macro planning succeeded')
