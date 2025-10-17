local json = require("integration.json")
local util = require("integration.util")

local DEFAULT_CONFIG = {
    aggression = 0.65,
    retreatHpThreshold = 0.25,
    healHpThreshold = 0.5,
    healManaThreshold = 0.35,
    farmSearchRadius = 1600,
    roamSearchRadius = 2200,
    fightEngageThreshold = 0.58,
    pushWaveRange = 2800,
    logLevel = "INFO",
    logLimitPerTick = 12,
    debug = false,
    pursueTimeout = 3.5,
    runePrepTime = 10,
    runeInterval = 120,
    pullPrepWindow = 7,
    stackPrepWindow = 7,
    farmSafetyBias = 0.35,
    gankSoloDistance = 1800,
    shopMinGold = 300,
    orbwalkHold = 0.12,
    orbwalkMoveStep = 120,
    dangerDecay = 0.92,
    rotationCooldown = 18,
    tpDefendThreshold = 0.55,
    farmHeatmapDecay = 0.85,
    economy = {
        forceTp = true,
        allowGreed = true,
        farmAccelerators = true,
    },
    nav = {
        safeWaypointRadius = 900,
    },
}

local CONFIG_FILENAME = "config.json"

local function deep_copy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = deep_copy(v)
    end
    return copy
end

local function apply_defaults(cfg, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(cfg[key]) ~= "table" then
                cfg[key] = deep_copy(value)
            else
                apply_defaults(cfg[key], value)
            end
        elseif cfg[key] == nil then
            cfg[key] = value
        end
    end
end

local function safe_load()
    local path = util.resolve_path(CONFIG_FILENAME)
    local ok, cfg = pcall(json.load, path)
    if ok and type(cfg) == "table" then
        apply_defaults(cfg, DEFAULT_CONFIG)
        return cfg
    end

    local reason
    if ok then
        reason = string.format("invalid config structure (%s)", path)
    else
        reason = string.format("%s (%s)", tostring(cfg), path)
    end

    print("[ERROR] Failed to load config.json: " .. reason)
    local fallback = deep_copy(DEFAULT_CONFIG)
    return fallback
end

return safe_load()
