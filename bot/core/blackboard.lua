local api = require("bot.integration.uc_api")
local util = require("bot.core.util")

local Blackboard = {}
Blackboard.__index = Blackboard

local function empty_state()
  return {
    self = nil,
    allies = {},
    enemies = {},
    creeps = {},
    neutrals = {},
    structures = {},
    lastDamage = nil,
    lastSeenTime = {},
    cooldowns = {},
    mana = 0,
    hp = 0,
    maxHp = 1,
    maxMana = 1,
    winChance = 0.5,
    threat = 0,
    safe = true,
    needGold = false,
    healReady = false,
    waveAdvantage = false,
    combatRange = 650,
    aggression = 0.5,
    retreatUntil = 0,
  }
end

function Blackboard.new()
  local self = setmetatable({}, Blackboard)
  self.state = empty_state()
  return self
end

function Blackboard:reset()
  self.state = empty_state()
end

function Blackboard:updateSelf(npc)
  self.state.self = npc
  if npc then
    self.state.hp = api.get_health(npc)
    self.state.maxHp = api.get_max_health(npc)
    self.state.mana = api.get_mana(npc)
    self.state.maxMana = api.get_max_mana(npc)
    self.state.combatRange = api.get_attack_range(npc)
  end
end

function Blackboard:updateAllies(list)
  self.state.allies = list or {}
end

function Blackboard:updateEnemies(list)
  self.state.enemies = list or {}
end

function Blackboard:updateCreeps(list)
  self.state.creeps = list or {}
end

function Blackboard:updateNeutrals(list)
  self.state.neutrals = list or {}
end

function Blackboard:updateStructures(list)
  self.state.structures = list or {}
end

function Blackboard:updateCooldown(abilityId, remaining)
  self.state.cooldowns[abilityId] = remaining
end

function Blackboard:setNeedGold(flag)
  self.state.needGold = flag
end

function Blackboard:setHealReady(flag)
  self.state.healReady = flag
end

function Blackboard:setWaveAdvantage(flag)
  self.state.waveAdvantage = flag
end

function Blackboard:setWinChance(val)
  self.state.winChance = util.clamp(val, 0, 1)
end

function Blackboard:setThreat(val)
  self.state.threat = math.max(0, val)
end

function Blackboard:setSafe(flag)
  self.state.safe = flag
end

function Blackboard:setAggression(value)
  self.state.aggression = util.clamp(value, 0, 1)
end

function Blackboard:flagRetreatUntil(time)
  self.state.retreatUntil = time
end

function Blackboard:isRetreating(time)
  return time < (self.state.retreatUntil or 0)
end

function Blackboard:lastHit(amount, source)
  self.state.lastDamage = { amount = amount, source = source, time = api.get_time() }
end

function Blackboard:updateEnemy(entity)
  if not entity then
    return
  end
  local id = api.get_entity_index(entity)
  if not id then
    return
  end
  self.state.lastSeenTime[id] = api.get_time()
  local found = false
  for idx, enemy in ipairs(self.state.enemies) do
    if api.get_entity_index(enemy) == id then
      self.state.enemies[idx] = entity
      found = true
      break
    end
  end
  if not found then
    table.insert(self.state.enemies, entity)
  end
end

function Blackboard:canUse(abilityId)
  local cooldown = self.state.cooldowns[abilityId]
  return not cooldown or cooldown <= 0
end

function Blackboard:hpRatio()
  if self.state.maxHp <= 0 then
    return 0
  end
  return self.state.hp / self.state.maxHp
end

function Blackboard:manaRatio()
  if self.state.maxMana <= 0 then
    return 0
  end
  return self.state.mana / self.state.maxMana
end

function Blackboard:bestTargetInRange(range)
  local selfUnit = self.state.self
  if not selfUnit then
    return nil
  end
  local bestTarget = nil
  local bestScore = -math.huge
  for _, enemy in ipairs(self.state.enemies) do
    if api.is_alive(enemy) then
      local dist = api.distance_between_units(selfUnit, enemy)
      if not range or dist <= range then
        local hp = api.get_health(enemy)
        local disableScore = api.is_disabled(enemy) and 200 or 0
        local lowHpScore = math.max(0, 600 - hp)
        local score = disableScore + lowHpScore + api.get_soft_value(enemy, "priority", 0)
        if score > bestScore then
          bestScore = score
          bestTarget = enemy
        end
      end
    end
  end
  return bestTarget
end

function Blackboard:canKill(target)
  if not target then
    return false
  end
  local targetHp = api.get_health(target)
  local selfUnit = self.state.self
  if not selfUnit then
    return false
  end
  local baseDamage = api.get_attack_damage(selfUnit)
  local nukeDamage = api.estimate_spell_damage(selfUnit, "nuke")
  return (baseDamage + nukeDamage) >= targetHp
end

function Blackboard:safeFarmTarget()
  local selfUnit = self.state.self
  if not selfUnit then
    return nil
  end
  local bestCreep
  local lowestHp = math.huge
  for _, creep in ipairs(self.state.creeps) do
    if api.is_alive(creep) then
      local dist = api.distance_between_units(selfUnit, creep)
      if dist <= self.state.combatRange + 100 then
        local hp = api.get_health(creep)
        if hp < lowestHp then
          lowestHp = hp
          bestCreep = creep
        end
      end
    end
  end
  return bestCreep
end

function Blackboard:frontWavePos()
  if #self.state.creeps == 0 then
    return nil
  end
  local centroid = { x = 0, y = 0, z = 0 }
  local count = 0
  for _, creep in ipairs(self.state.creeps) do
    if api.is_alive(creep) then
      local pos = api.get_position(creep)
      centroid.x = centroid.x + pos.x
      centroid.y = centroid.y + pos.y
      centroid.z = centroid.z + (pos.z or 0)
      count = count + 1
    end
  end
  if count == 0 then
    return nil
  end
  centroid.x = centroid.x / count
  centroid.y = centroid.y / count
  centroid.z = centroid.z / count
  return centroid
end

return Blackboard
