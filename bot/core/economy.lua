local api = require("integration.uc_api")
local bb = require("core.blackboard")
local util = require("core.util")
local log = require("integration.log")

local M = {
    _lastPurchase = 0,
}

local BASE_BUILDS = {
    carry = {
        "item_quelling_blade",
        "item_power_treads",
        "item_maelstrom",
        "item_black_king_bar",
        "item_satanic",
        "item_monkey_king_bar",
    },
    mid = {
        "item_bottle",
        "item_boots_of_travel",
        "item_kaya_and_sange",
        "item_sheepstick",
        "item_black_king_bar",
        "item_octarine_core",
    },
    off = {
        "item_vanguard",
        "item_guardian_greaves",
        "item_crimson_guard",
        "item_pipe",
        "item_shivas_guard",
        "item_refresher",
    },
    soft = {
        "item_arcane_boots",
        "item_glimmer_cape",
        "item_force_staff",
        "item_spirit_vessel",
        "item_aghanims_shard",
        "item_octarine_core",
    },
    hard = {
        "item_tranquil_boots",
        "item_magic_wand",
        "item_mekansm",
        "item_pipe",
        "item_solar_crest",
        "item_gem",
    },
}

local SKILL_PLANS = {
    default = { "skill1", "skill2", "skill1", "skill3", "skill1", "ultimate" },
    carry = { "skill2", "skill1", "skill2", "skill3", "skill2", "ultimate" },
    mid = { "skill1", "skill2", "skill1", "skill3", "skill1", "ultimate" },
}

local COUNTERS = {
    magic = { "item_black_king_bar", "item_pipe" },
    silence = { "item_manta", "item_black_king_bar" },
    illusions = { "item_maelstrom", "item_battle_fury" },
    healers = { "item_spirit_vessel" },
    mobile = { "item_orchid", "item_sheepstick" },
    evasion = { "item_monkey_king_bar" },
}

local function add_counter(plan, items)
    for _, item in ipairs(items) do
        local seen = false
        for _, existing in ipairs(plan) do
            if existing == item then
                seen = true
                break
            end
        end
        if not seen then
            table.insert(plan, item)
        end
    end
end

local function cost_of(item)
    if not item then
        return 0
    end
    if Shop and Shop.GetItemCost then
        local ok, cost = pcall(Shop.GetItemCost, item)
        if ok and cost then
            return cost
        end
    end
    local FALLBACK = {
        item_quelling_blade = 100,
        item_power_treads = 1400,
        item_maelstrom = 2700,
        item_black_king_bar = 4050,
        item_satanic = 5050,
        item_monkey_king_bar = 4975,
        item_bottle = 675,
        item_boots_of_travel = 2500,
        item_kaya_and_sange = 4100,
        item_sheepstick = 5700,
        item_octarine_core = 5275,
        item_vanguard = 1825,
        item_guardian_greaves = 4900,
        item_crimson_guard = 3600,
        item_pipe = 3475,
        item_shivas_guard = 4850,
        item_refresher = 5000,
        item_arcane_boots = 1300,
        item_glimmer_cape = 1950,
        item_force_staff = 2200,
        item_spirit_vessel = 2980,
        item_aghanims_shard = 1400,
        item_tranquil_boots = 925,
        item_magic_wand = 450,
        item_mekansm = 1775,
        item_solar_crest = 2625,
        item_gem = 900,
        item_manta = 4600,
        item_battle_fury = 4100,
        item_orchid = 3475,
    }
    return FALLBACK[item] or 1000
end

function M.planBuild(role, enemyHints)
    local base = BASE_BUILDS[role or "carry"] or BASE_BUILDS.carry
    local plan = util.deep_copy(base)
    local skillPlan = SKILL_PLANS[role or "default"] or SKILL_PLANS.default

    if enemyHints then
        if enemyHints.magicHeavy then
            add_counter(plan, COUNTERS.magic)
        end
        if enemyHints.silencers then
            add_counter(plan, COUNTERS.silence)
        end
        if enemyHints.illusions then
            add_counter(plan, COUNTERS.illusions)
        end
        if enemyHints.healers then
            add_counter(plan, COUNTERS.healers)
        end
        if enemyHints.mobileCores then
            add_counter(plan, COUNTERS.mobile)
        end
        if enemyHints.evasion then
            add_counter(plan, COUNTERS.evasion)
        end
    end

    if bb.config.economy and bb.config.economy.farmAccelerators then
        if role == "carry" or role == "mid" then
            add_counter(plan, { "item_hand_of_midas" })
        end
    end

    bb.enemyHints = enemyHints or {}
    bb:setPlans(plan, skillPlan)
    bb.buyQueue = {}
    local owned = {}
    if bb.heroData and bb.heroData.items then
        for name in pairs(bb.heroData.items) do
            owned[name] = true
        end
    end
    for _, item in ipairs(plan) do
        if not owned[item] then
            bb:enqueueBuy(item)
        end
    end
    return plan, skillPlan
end

local function ensure_tp()
    if not bb.config.economy or not bb.config.economy.forceTp then
        return
    end
    if api.tpReady() then
        return
    end
    local queue = bb.buyQueue
    local hasTpQueued = false
    for _, item in ipairs(queue) do
        if item == "item_tpscroll" then
            hasTpQueued = true
            break
        end
    end
    if not hasTpQueued then
        table.insert(queue, 1, "item_tpscroll")
    end
end

local function should_buy(item, gold)
    local cost = cost_of(item)
    if gold >= cost then
        return true
    end
    if cost - gold <= (bb.config.shopMinGold or 250) then
        return true
    end
    return false
end

local function perform_purchase(item, time)
    if not item then
        return false
    end
    if not api.canBuy(item) then
        return false
    end
    if not api.buy(item) then
        return false
    end
    log.info("Bought " .. item)
    M._lastPurchase = time
    if item ~= "item_tpscroll" then
        api.stashPull()
        api.courierSend()
    end
    return true
end

local function learn_skills()
    local available = api.availableSkills()
    if not available or #available == 0 then
        return
    end
    local plan = bb.skillPlan or {}
    for _, target in ipairs(plan) do
        for _, name in ipairs(available) do
            if name == target then
                api.learnSkill(name)
                log.debug("Learned skill " .. name)
                return
            end
        end
    end
    local fallback = available[1]
    if fallback then
        api.learnSkill(fallback)
        log.debug("Learned fallback skill " .. fallback)
    end
end

function M.tick(time)
    ensure_tp()
    learn_skills()
    local gold = api.currentGold()
    local item = bb:peekBuy()
    if not item then
        return
    end
    if should_buy(item, gold) then
        if perform_purchase(item, time) then
            bb:dequeueBuy()
        end
    end
end

return M
