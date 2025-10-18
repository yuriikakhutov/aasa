---@class Utility
local Utility = {}

local DEFAULT_WEIGHTS = {
    farm = 0.5,
    push = 0.4,
    defend = 0.4,
    gank = 0.3,
    rune = 0.2,
    roshan = 0.1,
    retreat = 0.2,
    regroup = 0.2
}

---@param snapshot table
---@param memory table
---@return table
function Utility.score(snapshot, memory)
    if not snapshot or not snapshot.selfUnit then
        return DEFAULT_WEIGHTS
    end

    local weights = {}
    for k, v in pairs(DEFAULT_WEIGHTS) do
        weights[k] = v
    end

    local selfUnit = snapshot.selfUnit
    local hpRatio = (selfUnit.health or 1) / math.max(selfUnit.maxHealth or 1, 1)
    if hpRatio < 0.35 then
        weights.retreat = weights.retreat + 0.6
        weights.farm = weights.farm * 0.5
    end

    local enemyCount = #(snapshot.enemies or {})
    local allyCount = #(snapshot.allies or {})
    if enemyCount > allyCount + 1 then
        weights.defend = weights.defend + 0.4
        weights.retreat = weights.retreat + 0.3
    elseif allyCount >= enemyCount then
        weights.push = weights.push + 0.3
        weights.gank = weights.gank + 0.2
    end

    if snapshot.runes and #snapshot.runes > 0 then
        weights.rune = weights.rune + 0.3
    end

    if selfUnit.level and selfUnit.level >= 16 then
        weights.roshan = weights.roshan + 0.2
    end

    return weights
end

return Utility
