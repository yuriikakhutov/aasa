---@class Economy
local Economy = {}

---@param snapshot table
---@return boolean
function Economy.shouldLastHit(snapshot)
    if not snapshot or not snapshot.selfUnit then
        return false
    end
    if snapshot.selfUnit.health and snapshot.selfUnit.health < (snapshot.selfUnit.maxHealth or 1) * 0.3 then
        return false
    end
    return true
end

return Economy
