local hooks = require("integration.hooks")
local events = require("core.events")
local perception = require("core.perception")
local selector = require("core.selector")
local scheduler = require("core.scheduler")
local bb = require("core.blackboard")
local config = require("config")
local api = require("integration.uc_api")
local util = require("core.util")

bb:init(config)

local function on_tick(evt)
    perception.scan(evt.dt)
    local mode = selector.decide(evt.time)
    scheduler.run(mode, evt.time)
end

events.on("tick", on_tick)

events.on("entity_create", function(evt)
    bb:updateEnemy({ entity = evt.entity })
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
