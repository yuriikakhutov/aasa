local json = require("integration.json")

local DEFAULT_CONFIG = {
    aggression = 0.5,
    vision_range = 800,
}

local function module_dir()
    local info = debug.getinfo(1, "S")
    if not info or not info.source then
        return ""
    end

    local source = info.source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end

    local dir = source:match("^(.*[/\\])")
    return dir or ""
end

local function build_config_path()
    local dir = module_dir()
    if dir == "" then
        return "config.json"
    end
    return dir .. "config.json"
end

local function clone_default()
    return {
        aggression = DEFAULT_CONFIG.aggression,
        vision_range = DEFAULT_CONFIG.vision_range,
    }
end

local function safe_load()
    local path = build_config_path()
    local ok, cfg = pcall(json.load, path)
    if not ok or type(cfg) ~= "table" then
        local reason = ok and "invalid config structure" or tostring(cfg)
        print("[ERROR] Failed to load config.json: " .. tostring(reason))
        return clone_default()
    end
    return cfg
end

return safe_load()
