_G.Enum = {
  TeamType = { TEAM_FRIENDLY = 2, TEAM_ENEMY = 3 },
  UnitType = { TEAM_CREEP = 1, LANE_CREEP = 2 },
  UnitOrder = {},
  PlayerOrderIssuer = {},
  ModifierState = {},
}

function _G.Vector(x, y, z)
  return { x = x, y = y, z = z }
end

local selector = require("bot.core.selector")
local Blackboard = require("bot.core.blackboard")
local config = require("bot.config").load()

local bb = Blackboard.new()

bb.state.safe = true
bb.state.needGold = true
bb:setThreat(0.1)
bb:setWinChance(0.3)

local mode = selector.decide(bb, config, 10)
assert(mode == "roam" or mode == "farm", "Expected roam or farm, got " .. tostring(mode))

bb:setThreat(2.0)
mode = selector.decide(bb, config, 12)
assert(mode == "retreat", "Expected retreat under heavy threat")

print("test_selector.lua passed")
