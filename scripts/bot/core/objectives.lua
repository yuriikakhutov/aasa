---
-- Objective helpers: standardises macro directives between modules.
---

local Objectives = {}
Objectives.Types = {
    FarmSafe = "FarmSafe",
    FarmAggressive = "FarmAggressive",
    PushTier = "PushTier",
    DefendTier = "DefendTier",
    GankHero = "GankHero",
    ControlRune = "ControlRune",
    TakeRoshan = "TakeRoshan",
    Retreat = "Retreat",
    Regroup = "Regroup",
}

function Objectives.new(kind, params)
    return {
        kind = kind,
        params = params or {},
        createdAt = os.clock(),
    }
end

return Objectives
