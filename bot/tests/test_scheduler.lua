_G.Enum = {
  TeamType = { TEAM_FRIENDLY = 2, TEAM_ENEMY = 3 },
  UnitType = { TEAM_CREEP = 1 },
  UnitOrder = { DOTA_UNIT_ORDER_MOVE_TO_POSITION = 1 },
  PlayerOrderIssuer = { DOTA_ORDER_ISSUER_HERO_ONLY = 1 },
}

function _G.Vector(x, y, z)
  return { x = x, y = y, z = z }
end

local scheduler = require("bot.core.scheduler")
local Blackboard = require("bot.core.blackboard")
local config = require("bot.config").load()

local bb = Blackboard.new()

scheduler.enqueue("farm", 0, config)
scheduler.enqueue("fight", 0.2, config)
scheduler.enqueue("retreat", 0.4, config)

scheduler.run(bb, config, 0.5)
scheduler.run(bb, config, 0.6)
scheduler.run(bb, config, 0.7)

print("test_scheduler.lua passed")
