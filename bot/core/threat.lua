local api = require("bot.integration.uc_api")
local util = require("bot.core.util")

local threat = {}

local function count_nearby_enemies(hero, radius)
  local enemies = api.get_enemies_around(hero, radius)
  local count, totalHp = 0, 0
  for i = 1, #enemies do
    local enemy = enemies[i]
    if api.is_alive(enemy) then
      count = count + 1
      totalHp = totalHp + api.get_health(enemy)
    end
  end
  return count, totalHp
end

function threat.evaluate(bb, cfg)
  local hero = bb.state.self
  if not hero then
    return 0
  end
  local hpRatio = bb:hpRatio()
  local enemyCount, enemyHealth = count_nearby_enemies(hero, cfg.dangerRadius)
  local meleeThreat = api.get_enemies_around(hero, 450)
  local meleeCount = 0
  for i = 1, #meleeThreat do
    local unit = meleeThreat[i]
    if api.is_alive(unit) then
      meleeCount = meleeCount + 1
    end
  end

  local threatScore = enemyCount * 1.2 + meleeCount * 0.5
  if hpRatio < cfg.retreatHpThreshold then
    threatScore = threatScore + (cfg.retreatHpThreshold - hpRatio) * 5
  end
  if enemyHealth > 0 then
    threatScore = threatScore + util.clamp(enemyHealth / 2000, 0, 3)
  end
  return threatScore
end

return threat
