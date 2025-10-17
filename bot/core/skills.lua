local api = require("bot.integration.uc_api")
local movement = require("bot.core.movement")

local skills = {}

local function cast_if_ready(bb, abilityName, target, position)
  local hero = bb.state.self
  local player = bb.state.player or api.get_local_player()
  if not hero or not player then
    return false
  end
  local ability = api.get_ability_by_name(hero, abilityName)
  if not ability or not api.can_cast_ability(hero, ability) then
    return false
  end
  if target then
    return api.cast_ability_on_target(player, ability, target)
  elseif position then
    return api.cast_ability_on_position(player, ability, position)
  else
    return api.cast_ability_on_position(player, ability, api.get_position(hero))
  end
end

function skills.try_execute_combo(bb, target, cfg)
  if cast_if_ready(bb, "disable", target) then
    return true
  end
  if bb:canKill(target) and cast_if_ready(bb, "nuke", target) then
    return true
  end
  if cast_if_ready(bb, "burst", target) then
    return true
  end
  return false
end

function skills.try_escape(bb, cfg)
  local hero = bb.state.self
  if not hero then
    return false
  end
  local fountain = require("bot.integration.nav").get_fountain_position(api.get_team(hero))
  if cast_if_ready(bb, "escape", nil, fountain) then
    return true
  end
  return false
end

function skills.try_heal(bb)
  return cast_if_ready(bb, "heal")
end

return skills
