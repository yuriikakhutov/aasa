local actions = require("bot.core.actions")

local scheduler = {}

local queue = {}
local lastKey = nil
local lastTime = 0

local function throttle(key, now, cooldown)
  if key == lastKey and (now - lastTime) < cooldown then
    return true
  end
  lastKey = key
  lastTime = now
  return false
end

function scheduler.enqueue(mode, now, cfg)
  if throttle(mode, now, 0.1) then
    return
  end
  queue[#queue + 1] = mode
  if #queue > cfg.maxQueuedActions then
    table.remove(queue, 1)
  end
end

function scheduler.run(bb, cfg, now)
  if #queue == 0 then
    return
  end
  local mode = table.remove(queue, 1)
  if mode == "retreat" then
    actions.retreat(bb, cfg)
  elseif mode == "fight" then
    actions.fight(bb, cfg)
  elseif mode == "roam" then
    actions.roam(bb, cfg)
  elseif mode == "farm" then
    actions.farm(bb, cfg)
  elseif mode == "heal" then
    actions.heal(bb, cfg)
  elseif mode == "push" then
    actions.push(bb, cfg)
  elseif mode == "defend" then
    actions.defend(bb, cfg)
  end
end

return scheduler
