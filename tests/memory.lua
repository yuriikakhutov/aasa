local Memory = require('scripts.bot.core.memory')
local ProbPos = require('scripts.bot.core.probpos')

local memory = Memory.new()
local prob = ProbPos.new()

local sensors = {
    valid = true,
    time = 10,
    enemies = {
        { id = 1, pos = { x = 100, y = 200 }, health = 500, movespeed = 320 },
    },
    abilities = {},
}

memory:updateFromSensors(sensors)
prob:update(memory, sensors)

for id, entry in pairs(memory.enemies) do
    assert(entry.isVisible == true, 'enemy should be visible')
    assert(entry.position.x == 100, 'position persisted')
end

for id, estimate in pairs(prob.estimates) do
    assert(estimate.radius >= 0, 'radius computed')
end

print('[MEMORY] ok')
