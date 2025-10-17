local hooks = require("integration.hooks")
local events = require("core.events")
local perception = require("core.perception")
local selector = require("core.selector")
local scheduler = require("core.scheduler")
local bb = require("core.blackboard")
local config = require("config")
local api = require("integration.uc_api")
local util = require("core.util")
local log = require("integration.log")
local laning = require("core.laning")
local economy = require("core.economy")

log.configure(config)
bb:init(config)

local function on_spawn()
    bb:reset()
    laning.assign()
    economy.planBuild(bb.role or "carry", bb.enemyHints)
end

local function on_tick(evt)
    log.tick(evt.time)
    local now = evt.time or api.time()
    if api.isPlayerControlling and api.isPlayerControlling() then
        bb:setUserOverride(now + 2)
    end
    perception.scan(evt.dt)
    economy.tick(now)
    local mode = selector.decide(now)
    if bb:isUserOverride(now) then
        return
    end
    scheduler.run(mode, now)
end

events.on("tick", on_tick)

events.on("entity_create", function(evt)
    if evt.entity and evt.entity == api.self() then
        on_spawn()
    else
        bb:updateEnemy({ entity = evt.entity })
    end
end)

events.on("damage", function(evt)
    if not evt.data then
        return
    end
    local target = evt.data.target
    if target and api.self() and target == api.self() then
        bb:lastHit(evt.data.damage or 0, evt.data.source)
    end
end)

events.on("entity_killed", function(evt)
    if not evt.data or not evt.data.target then
        return
    end
    if api.self() and evt.data.target == api.self() then
        bb:reset()
    end
end)

return hooks.build()
