local api = require("bot.integration.uc_api")
local movement = require("bot.core.movement")
local items = require("bot.core.items")

local tactics = {}

function tactics.select_target(bb, cfg)
  local focus = bb:bestTargetInRange(cfg.maxChaseDistance)
  if focus then
    return focus
  end
  local enemies = bb.state.enemies or {}
  local hero = bb.state.self
  local best
  local bestDist = math.huge
  for _, enemy in ipairs(enemies) do
    if api.is_alive(enemy) then
      local dist = api.distance_between_units(hero, enemy)
      if dist < bestDist then
        bestDist = dist
        best = enemy
      end
    end
  end
  return best
end

function tactics.after_attack(bb, target, cfg)
  movement.kite(bb, cfg, target)
  if bb:hpRatio() < 0.4 then
    items.try_healing(bb)
  end
end

return tactics
