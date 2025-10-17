local api = require("bot.integration.uc_api")
local movement = require("bot.core.movement")
local combat = require("bot.core.combat")
local skills = require("bot.core.skills")
local items = require("bot.core.items")
local behaviors = require("bot.ai.behaviors")

local actions = {}

local function ensure_player(bb)
  if not bb.state.player then
    bb.state.player = api.get_local_player()
  end
  return bb.state.player
end

function actions.retreat(bb, cfg)
  local player = ensure_player(bb)
  if not player then
    return
  end
  movement.retreat(bb, cfg)
  skills.try_escape(bb, cfg)
end

function actions.heal(bb, cfg)
  local player = ensure_player(bb)
  if not player then
    return
  end
  skills.try_heal(bb)
end

function actions.farm(bb, cfg)
  behaviors.farm(bb, cfg)
end

function actions.roam(bb, cfg)
  behaviors.roam(bb, cfg)
end

function actions.push(bb, cfg)
  behaviors.push(bb, cfg)
end

function actions.defend(bb, cfg)
  behaviors.defend(bb, cfg)
end

function actions.fight(bb, cfg)
  local player = ensure_player(bb)
  if not player then
    return
  end
  combat.engage(bb, cfg)
end

return actions
