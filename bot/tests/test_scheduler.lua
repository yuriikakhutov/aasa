local scheduler = require("core.scheduler")
local actions = require("core.actions")

return function()
    local executed = {}
    local original = actions.execute
    actions.execute = function(mode)
        table.insert(executed, mode)
    end
    scheduler.cooldown = 0.1
    scheduler.lastCommand.time = -math.huge
    scheduler.run("farm", 1.0)
    scheduler.run("farm", 1.05)
    scheduler.run("farm", 1.2)
    actions.execute = original
    assert(#executed == 2, "Scheduler should throttle duplicate commands")
    return true
end
