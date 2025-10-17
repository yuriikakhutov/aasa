local util = require("bot.core.util")

local config = {}
local cache

local function default_config()
  return {
    debug = false,
    logLevel = "INFO",
    aggression = 0.5,
    farmRadius = 1400,
    roamRadius = 2200,
    retreatHpThreshold = 0.3,
    retreatManaThreshold = 0.15,
    fightWinChance = 0.55,
    healHpThreshold = 0.5,
    maxQueuedActions = 6,
    logRateLimit = 0.25,
    maxLogEntries = 500,
    dangerRadius = 1600,
    kiteRange = 450,
    maxChaseDistance = 1800,
    fallbackSafeTime = 4.0,
  }
end

function config.load()
  if cache then
    return cache
  end
  local cfg, err = util.load_json("bot/config.json")
  if not cfg then
    cfg = default_config()
  else
    for key, value in pairs(default_config()) do
      if cfg[key] == nil then
        cfg[key] = value
      end
    end
  end
  cache = cfg
  return cache
end

function config.reload()
  cache = nil
  return config.load()
end

return config
