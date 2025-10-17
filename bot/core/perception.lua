local api = require("bot.integration.uc_api")
local threat = require("bot.core.threat")

local perception = {}

function perception.scan(bb, cfg)
  local hero = api.get_local_hero()
  bb:updateSelf(hero)
  if not hero then
    return
  end
  local player = api.get_local_player()
  bb.state.player = player

  local team = api.get_team(hero)
  local allies = api.get_allies_around(hero, cfg.roamRadius)
  local enemies = api.get_enemies_around(hero, cfg.roamRadius)
  local creeps = api.get_lane_creeps(team)
  local neutrals = api.get_neutrals(cfg.roamRadius)
  local structures = api.get_structures(team)

  bb:updateAllies(allies)
  bb:updateEnemies(enemies)
  bb:updateCreeps(creeps)
  bb:updateNeutrals(neutrals)
  bb:updateStructures(structures)

  -- update cooldowns for tracked abilities
  local abilityNames = { "nuke", "disable", "escape", "heal" }
  for _, name in ipairs(abilityNames) do
    local ability = api.get_ability_by_name(hero, name)
    if ability then
      local remaining = api.get_spell_cooldown(hero, ability)
      bb:updateCooldown(name, remaining)
      if name == "heal" then
        bb:setHealReady(remaining <= 0 and api.can_cast_ability(hero, ability))
      end
    end
  end

  bb:setAggression(cfg.aggression)

  local goldNeeded = 0
  if NPC and NPC.GetItemByIndex then
    for slot = 0, 5 do
      local item = NPC.GetItemByIndex(hero, slot)
      if item and Ability and Ability.GetName then
        local name = Ability.GetName(item)
        if name == "item_blink" then
          goldNeeded = goldNeeded + 2250
        end
      end
    end
  end
  bb:setNeedGold(goldNeeded > 0)

  local hpRatio = bb:hpRatio()
  local manaRatio = bb:manaRatio()
  local safe = hpRatio > cfg.retreatHpThreshold and manaRatio > cfg.retreatManaThreshold
  bb:setSafe(safe)
  local threatScore = threat.evaluate(bb, cfg)
  bb:setThreat(threatScore)

  local alliesCount = 0
  for _, ally in ipairs(allies) do
    if api.is_alive(ally) then
      alliesCount = alliesCount + 1
    end
  end
  local enemiesCount = 0
  for _, enemy in ipairs(enemies) do
    if api.is_alive(enemy) then
      enemiesCount = enemiesCount + 1
    end
  end

  local winChance = 0.5
  if alliesCount + enemiesCount > 0 then
    winChance = (alliesCount + 1) / (alliesCount + enemiesCount + 1)
    winChance = winChance * (hpRatio + 0.5)
    winChance = math.min(1, winChance)
  end
  bb:setWinChance(winChance)

  local frontWave = bb:frontWavePos()
  bb:setWaveAdvantage(frontWave ~= nil)
end

return perception
