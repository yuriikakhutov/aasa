local json = require("integration.json")
local util = require("integration.util")

local DEFAULT_CONFIG = {
    aggression = 0.5,
    vision_range = 800,
}

local CONFIG_FILENAME = "config.json"

local function clone_default()
    return {
        aggression = DEFAULT_CONFIG.aggression,
        vision_range = DEFAULT_CONFIG.vision_range,
    }
end

local function safe_load()
    local path = util.resolve_path(CONFIG_FILENAME)
    local ok, cfg = pcall(json.load, path)
    if ok and type(cfg) == "table" then
        return cfg
    end

    local reason
    if ok then
        reason = string.format("invalid config structure (%s)", path)
    else
        reason = string.format("%s (%s)", tostring(cfg), path)
    end

    print("[ERROR] Failed to load config.json: " .. reason)
    return clone_default()
end

return safe_load()
