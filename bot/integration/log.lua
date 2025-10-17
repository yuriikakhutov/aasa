local util = require("core.util")

local M = {
    _config = nil,
}

local LEVEL_ORDER = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
}

local function allow(level)
    local cfg = M._config or {}
    local target = string.upper(cfg.logLevel or "INFO")
    local current = string.upper(level)
    if current == "DEBUG" then
        return cfg.debug == true
    end
    local required = LEVEL_ORDER[current] or 3
    local threshold = LEVEL_ORDER[target] or 3
    return required <= threshold or cfg.debug == true
end

function M.configure(cfg)
    M._config = cfg
    util.init(cfg)
end

function M.tick(game_time)
    util.tick_reset(game_time)
end

function M.error(msg)
    if allow("ERROR") then
        util.log("ERROR", msg)
    end
end

function M.warn(msg)
    if allow("WARN") then
        util.log("WARN", msg)
    end
end

function M.info(msg)
    if allow("INFO") then
        util.log("INFO", msg)
    end
end

function M.debug(msg)
    if allow("DEBUG") then
        util.log("DEBUG", msg)
    end
end

function M.d(msg)
    M.debug(msg)
end

return M
