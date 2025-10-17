local economy = require("core.economy")
local bb = require("core.blackboard")
local api = require("integration.uc_api")

return function()
    bb:reset()
    bb.config.economy = { forceTp = true, allowGreed = true, farmAccelerators = true }
    bb.heroData = { items = { item_power_treads = { handle = {} } }, abilities = {} }
    local plan = economy.planBuild("carry", { magicHeavy = true })
    local hasBkb = false
    for _, item in ipairs(plan) do
        if item == "item_black_king_bar" then
            hasBkb = true
        end
    end
    assert(hasBkb, "plan should include BKB against magic heavy lineups")
    for _, queued in ipairs(bb.buyQueue) do
        assert(queued ~= "item_power_treads", "owned items should not be re-queued")
    end

    local originalTpReady = api.tpReady
    local originalCurrentGold = api.currentGold
    local originalCanBuy = api.canBuy
    local originalBuy = api.buy
    local originalAvailableSkills = api.availableSkills

    local purchases = {}
    api.tpReady = function()
        return false
    end
    api.currentGold = function()
        return 5000
    end
    api.canBuy = function(item)
        return true
    end
    api.buy = function(item)
        table.insert(purchases, item)
        return true
    end
    api.availableSkills = function()
        return {}
    end

    economy.tick(10)
    assert(#purchases >= 1, "economy.tick should issue purchases when affordable")

    api.tpReady = originalTpReady
    api.currentGold = originalCurrentGold
    api.canBuy = originalCanBuy
    api.buy = originalBuy
    api.availableSkills = originalAvailableSkills

    return true
end
