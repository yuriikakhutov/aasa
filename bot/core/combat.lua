local api = require("bot.integration.uc_api")
local movement = require("bot.core.movement")
local skills = require("bot.core.skills")
local tactics = require("bot.ai.tactics")

local combat = {}

function combat.engage(bb, cfg)
  local hero = bb.state.self
  local player = bb.state.player or api.get_local_player()
  if not hero or not player then
    return
  end
  local target = tactics.select_target(bb, cfg)
  if not target then
    return
  end
  if skills.try_execute_combo(bb, target, cfg) then
    return
  end
  local distance = api.distance_between_units(hero, target)
  if distance > bb.state.combatRange then
    movement.follow(bb, api.get_position(target))
    return
  end
  api.attack_target(player, target)
  tactics.after_attack(bb, target, cfg)
end

return combat
