---
-- Team coordination primitives for multi-bot communication.
---

local Log = require("scripts.bot.core.log")
local Team = {}

function Team.assignRole(sensors)
    if not sensors or not sensors.self then
        return "core"
    end
    local slot = sensors.self.playerSlot or 1
    if slot <= 1 then
        return "carry"
    elseif slot <= 2 then
        return "mid"
    elseif slot <= 3 then
        return "offlane"
    elseif slot <= 4 then
        return "support4"
    end
    return "support5"
end

function Team.broadcastFocus(target)
    if not target then
        return
    end
    Log.debug("Team focus target: " .. tostring(target.name or target.id))
end

return Team
