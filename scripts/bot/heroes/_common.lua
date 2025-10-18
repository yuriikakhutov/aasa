local HeroCommon = {}

function HeroCommon.configure(blackboard)
    blackboard.hero = {
        name = "generic",
        preferences = {
            engageRange = 600
        }
    }
end

return HeroCommon
