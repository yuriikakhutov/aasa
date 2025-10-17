package.path = package.path .. ';bot/?.lua;bot/?/init.lua;bot/?/?.lua'

local hooks = require("bot.integration.hooks")
local perception = require("bot.core.perception")
local selector = require("bot.core.selector")
local scheduler = require("bot.core.scheduler")
local Blackboard = require("bot.core.blackboard")
local config = require("bot.config")
local logger = require("bot.core.logger")
local events = require("bot.core.events")

local bb = Blackboard.new()
local cfg = config.load()
logger.configure(cfg)

local function refresh_config()
  cfg = config.reload()
  logger.configure(cfg)
end

events.on("prepare_order", function(order)
  if cfg.debug then
    logger.debug("Order issued: " .. (order and order.order or "unknown"))
  end
end)

local function dispatch(evt)
  if evt.type == "scripts_loaded" then
    logger.info("UCZone AI bot initialized")
    bb:reset()
  elseif evt.type == "tick" then
    perception.scan(bb, cfg)
    local mode = selector.decide(bb, cfg, evt.time)
    scheduler.enqueue(mode, evt.time, cfg)
    scheduler.run(bb, cfg, evt.time)
  elseif evt.type == "entity_create" then
    if cfg.debug then
      logger.debug("Entity created")
    end
  elseif evt.type == "entity_destroy" then
    if cfg.debug then
      logger.debug("Entity destroyed")
    end
  elseif evt.type == "damage_taken" then
    bb:lastHit(evt.amount or 0, evt.source)
    if bb:hpRatio() < cfg.retreatHpThreshold then
      scheduler.enqueue("retreat", evt.time or 0, cfg)
    end
  elseif evt.type == "entity_killed" then
    if evt.target then
      bb:updateEnemy(evt.target)
    end
  end
end

return hooks.init(dispatch)
