local api = require("bot.integration.uc_api")
local nav = require("bot.integration.nav")
local util = require("bot.core.util")

local movement = {}

local lastMoveKey = ""
local lastMoveTime = 0

local function throttle(key, now, interval)
  if lastMoveKey == key and (now - lastMoveTime) < interval then
    return true
  end
  lastMoveKey = key
  lastMoveTime = now
  return false
end

function movement.patrol(bb, cfg, targetPos)
  local hero = bb.state.self
  local player = bb.state.player or api.get_local_player()
  if not hero or not player then
    return
  end
  local now = api.get_time()
  if throttle("patrol", now, cfg.logRateLimit) then
    return
  end
  local safePoint = nav.ensure_pathable(targetPos)
  api.move_to_position(player, safePoint)
end

function movement.retreat(bb, cfg)
  local hero = bb.state.self
  local player = bb.state.player or api.get_local_player()
  if not hero or not player then
    return
  end
  local fountain = nav.get_fountain_position(api.get_team(hero))
  local now = api.get_time()
  if throttle("retreat", now, 0.1) then
    return
  end
  local path = api.find_path(api.get_position(hero), fountain)
  if #path > 0 then
    api.move_to_position(player, path[1])
  else
    api.move_to_position(player, fountain)
  end
  bb:flagRetreatUntil(now + cfg.fallbackSafeTime)
end

function movement.kite(bb, cfg, enemy)
  local hero = bb.state.self
  local player = bb.state.player or api.get_local_player()
  if not hero or not player or not enemy then
    return
  end
  local heroPos = api.get_position(hero)
  local enemyPos = api.get_position(enemy)
  local dir = util.normalize2D({ x = heroPos.x - enemyPos.x, y = heroPos.y - enemyPos.y, z = 0 })
  local kiteTarget = util.add2D(heroPos, util.scale2D(dir, cfg.kiteRange))
  if nav.is_position_safe(kiteTarget) then
    api.move_to_position(player, kiteTarget)
  end
end

function movement.follow(bb, position)
  local player = bb.state.player or api.get_local_player()
  if not player or not position then
    return
  end
  api.move_to_position(player, position)
end

return movement
