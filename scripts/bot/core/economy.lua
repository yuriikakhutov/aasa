---
-- Economy heuristics: farming, stacking, last hitting decisions.
---

local Economy = {}

function Economy.decide(bb)
    local sensors = bb.sensors or {}
    local objective = bb.macro
    if not sensors.valid then
        return
    end

    if objective and objective.kind == "FarmSafe" then
        bb.economy = { mode = "last_hit" }
    elseif objective and objective.kind == "FarmAggressive" then
        bb.economy = { mode = "pressure" }
    else
        bb.economy = { mode = "neutral" }
    end
end

return Economy
