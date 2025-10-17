local api = require("bot.integration.uc_api")
local nav = require("bot.integration.nav")
local movement = require("bot.core.movement")

local behaviors = {}

function behaviors.farm(bb, cfg)
  local creep = bb:safeFarmTarget()
  local player = bb.state.player or api.get_local_player()
  if creep and player then
    api.attack_target(player, creep)
  else
    behaviors.roam(bb, cfg)
  end
end

function behaviors.roam(bb, cfg)
  local hero = bb.state.self
  if not hero then
    return
  end
  local roamPoint = nav.next_roam_point(hero)
  movement.patrol(bb, cfg, roamPoint)
end

function behaviors.push(bb, cfg)
  local wavePos = bb:frontWavePos()
  if wavePos then
    movement.follow(bb, wavePos)
  else
    behaviors.farm(bb, cfg)
  end
end

function behaviors.defend(bb, cfg)
  local structures = bb.state.structures or {}
  if #structures > 0 then
    movement.follow(bb, api.get_position(structures[1]))
  else
    behaviors.farm(bb, cfg)
  end
end

return behaviors
