---
-- Shared hero helpers for skill and item handling.
---

local HeroCommon = {}

function HeroCommon.prioritiseAbilities(abilities)
    table.sort(abilities, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    return abilities
end

return HeroCommon
