_G.Enum = {
  TeamType = { TEAM_FRIENDLY = 2, TEAM_ENEMY = 3 },
}

function _G.Vector(x, y, z)
  return { x = x, y = y, z = z }
end

_G.Entity = {
  GetHeroesInRadius = function()
    return {}
  end,
  GetAbsOrigin = function()
    return { x = 0, y = 0, z = 0 }
  end,
}

local threat = require("bot.core.threat")
local Blackboard = require("bot.core.blackboard")
local config = require("bot.config").load()

local bb = Blackboard.new()

bb.state.self = {}

bb.state.hp = 200
bb.state.maxHp = 1000

local score = threat.evaluate(bb, config)
assert(score >= 0, "Threat score should be non-negative")

print("test_threat.lua passed")
