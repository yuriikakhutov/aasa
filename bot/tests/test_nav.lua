if not _G.Vector then
    function _G.Vector(x, y, z)
        return { x = x, y = y, z = z }
    end
end

local nav = require("core.nav")

return function()
    local waypoint = nav.closestWaypoint(Vector(0, 0, 0))
    assert(waypoint ~= nil, "closestWaypoint should return a vector")
    local safe = nav.safeRetreat()
    assert(safe ~= nil, "safeRetreat should always provide a fallback")
    local roam = nav.nextRoamPoint()
    assert(roam ~= nil, "nextRoamPoint should cycle points")
    return true
end
