local json = require("integration.json")

local function safe_load()
    local ok, cfg = pcall(json.load, "bot/config.json")
    if not ok then
        error("Failed to load config.json: " .. tostring(cfg))
    end
    return cfg
end

return safe_load()
