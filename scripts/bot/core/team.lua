local Log = require("scripts.bot.core.log")

---@class Team
local Team = {}

local shared = {
    role = 4,
    focusTarget = nil,
    smokeReady = false
}

function Team.setRole(role)
    shared.role = role
end

function Team.focus(target)
    shared.focusTarget = target
end

function Team.getFocus()
    return shared.focusTarget
end

function Team.shouldJoinFight()
    return shared.focusTarget ~= nil
end

return Team
