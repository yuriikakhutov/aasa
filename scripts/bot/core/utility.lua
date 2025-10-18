---
-- Utility scoring across macro behaviours.
---

local Utility = {}

local function averageNetworth(allies)
    local total = 0
    local count = 0
    for _, ally in ipairs(allies or {}) do
        total = total + (ally.networth or ally.gold or 0)
        count = count + 1
    end
    if count == 0 then
        return 0
    end
    return total / count
end

local function heroHealthRatio(unit)
    if not unit or not unit.health or not unit.maxHealth or unit.maxHealth == 0 then
        return 1
    end
    return unit.health / unit.maxHealth
end

function Utility.evaluate(bb)
    local sensors = bb.sensors or {}
    local memory = bb.memory or {}
    local danger = bb.danger or {}

    local networth = sensors.self and sensors.self.networth or 0
    local teamNetworth = averageNetworth(sensors.allies)
    local healthRatio = heroHealthRatio(sensors.self)

    local scores = {
        farm = 0.4,
        push = 0.2,
        defend = 0.2,
        gank = 0.2,
        rune = 0.1,
        roshan = 0.05,
        retreat = 0.0,
        regroup = 0.1,
    }

    if healthRatio < 0.35 then
        scores.retreat = 1.0
        scores.farm = scores.farm * 0.3
        scores.gank = 0
    else
        scores.retreat = danger.threatLevel or 0
    end

    if networth < teamNetworth then
        scores.farm = scores.farm + 0.2
    else
        scores.push = scores.push + 0.15
        scores.gank = scores.gank + 0.15
    end

    if (sensors.runes and #sensors.runes > 0) or (memory.runes and next(memory.runes)) then
        scores.rune = scores.rune + 0.25
    end

    if sensors.roshan and sensors.self.level and sensors.self.level >= 18 then
        scores.roshan = scores.roshan + 0.3
    end

    if sensors.enemies and #sensors.enemies > 0 then
        scores.gank = scores.gank + 0.25
        scores.push = scores.push * 0.6
    end

    local sum = 0
    for _, v in pairs(scores) do
        sum = sum + math.max(v, 0)
    end
    if sum > 0 then
        for key, value in pairs(scores) do
            scores[key] = math.max(value, 0) / sum
        end
    end

    return scores
end

return Utility
