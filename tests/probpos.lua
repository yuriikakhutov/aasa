local ProbPos = require('scripts.bot.core.probpos')

local prob = ProbPos.new()
local memory = {
    enemies = {
        enemy1 = {
            time = 0,
            position = { x = 0, y = 0 },
            lastKnownSpeed = 300,
        },
    }
}

local sensors = { time = 2 }
prob:update(memory, sensors)

local estimate = prob.estimates.enemy1
assert(estimate.radius >= 600, 'radius grows with time')
print('[PROBPOS] ok')
