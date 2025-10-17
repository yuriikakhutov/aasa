local api = {}

local function safe_call(fn, ...)
  if not fn then
    return nil
  end
  return fn(...)
end

function api.get_time()
  if GameRules and GameRules.GetGameTime then
    return GameRules.GetGameTime()
  elseif GlobalVars and GlobalVars.curtime then
    return GlobalVars.curtime
  end
  return os.clock()
end

function api.get_frame_time()
  if GlobalVars and GlobalVars.frametime then
    return GlobalVars.frametime
  end
  return 0.03
end

function api.get_local_player()
  if Players and Players.GetLocal then
    return Players.GetLocal()
  end
  return nil
end

function api.get_local_hero()
  if Heroes and Heroes.GetLocal then
    return Heroes.GetLocal()
  end
  return nil
end

function api.get_team(entity)
  if not entity or not Entity or not Entity.GetTeamNum then
    return nil
  end
  return Entity.GetTeamNum(entity)
end

function api.get_position(entity)
  if not entity or not Entity or not Entity.GetAbsOrigin then
    return { x = 0, y = 0, z = 0 }
  end
  local pos = Entity.GetAbsOrigin(entity)
  return { x = pos.x, y = pos.y, z = pos.z }
end

function api.get_health(entity)
  if not entity or not Entity or not Entity.GetHealth then
    return 0
  end
  return math.max(Entity.GetHealth(entity), 0)
end

function api.get_max_health(entity)
  if not entity or not Entity or not Entity.GetMaxHealth then
    return 1
  end
  return math.max(Entity.GetMaxHealth(entity), 1)
end

function api.get_mana(entity)
  if not entity or not NPC or not NPC.GetMana then
    return 0
  end
  return math.max(NPC.GetMana(entity), 0)
end

function api.get_max_mana(entity)
  if not entity or not NPC or not NPC.GetMaxMana then
    return 1
  end
  return math.max(NPC.GetMaxMana(entity), 1)
end

function api.get_attack_range(entity)
  if not entity or not NPC or not NPC.GetAttackRange then
    return 600
  end
  return NPC.GetAttackRange(entity) + NPC.GetHullRadius(entity) + 25
end

function api.get_attack_damage(entity)
  if not entity or not NPC or not NPC.GetTrueDamage then
    return 0
  end
  return NPC.GetTrueDamage(entity)
end

function api.get_entity_index(entity)
  if not entity or not Entity or not Entity.GetIndex then
    return nil
  end
  return Entity.GetIndex(entity)
end

function api.is_alive(entity)
  if not entity or not Entity or not Entity.IsAlive then
    return false
  end
  return Entity.IsAlive(entity)
end

function api.is_disabled(entity)
  if not entity or not NPC then
    return false
  end
  if NPC.HasState and Enum and Enum.ModifierState then
    for _, state in ipairs({ Enum.ModifierState.MODIFIER_STATE_STUNNED, Enum.ModifierState.MODIFIER_STATE_HEXED, Enum.ModifierState.MODIFIER_STATE_ROOTED }) do
      if NPC.HasState(entity, state) then
        return true
      end
    end
  end
  return false
end

function api.get_soft_value(entity, key, default)
  if not entity or not entity.__softValues then
    return default
  end
  return entity.__softValues[key] or default
end

function api.distance_between_units(a, b)
  if not a or not b or not Entity or not Entity.GetAbsOrigin then
    return math.huge
  end
  local pa = Entity.GetAbsOrigin(a)
  local pb = Entity.GetAbsOrigin(b)
  local dx = pa.x - pb.x
  local dy = pa.y - pb.y
  return math.sqrt(dx * dx + dy * dy)
end

function api.get_enemies_around(entity, radius)
  if not entity or not Entity or not Entity.GetHeroesInRadius then
    return {}
  end
  return Entity.GetHeroesInRadius(entity, radius, Enum.TeamType.TEAM_ENEMY, true, true) or {}
end

function api.get_allies_around(entity, radius)
  if not entity or not Entity or not Entity.GetHeroesInRadius then
    return {}
  end
  return Entity.GetHeroesInRadius(entity, radius, Enum.TeamType.TEAM_FRIENDLY, true, true) or {}
end

function api.get_lane_creeps(team)
  if not NPC or not NPC.GetUnitsInRadius or not GameRules or not GameRules.GetGameTime then
    return {}
  end
  local hero = api.get_local_hero()
  if not hero then
    return {}
  end
  local unitFlags = nil
  if Enum and Enum.UnitType and Enum.UnitType.TEAM_CREEP and Enum.UnitType.LANE_CREEP then
    unitFlags = (Enum.UnitType.TEAM_CREEP)
    if type(Enum.UnitType.LANE_CREEP) == "number" then
      unitFlags = unitFlags + Enum.UnitType.LANE_CREEP
    end
  end
  local teamFlag = Enum and Enum.TeamType and (Enum.TeamType.TEAM_BOTH or Enum.TeamType.TEAM_ENEMY) or nil
  return Entity.GetUnitsInRadius(hero, 1800, teamFlag, unitFlags, true) or {}
end

function api.get_neutrals(radius)
  local hero = api.get_local_hero()
  if not hero or not Entity or not Entity.GetUnitsInRadius then
    return {}
  end
  return Entity.GetUnitsInRadius(hero, radius, Enum.TeamType.TEAM_ENEMY, Enum.UnitType.NEUTRAL_CREEP, true) or {}
end

function api.get_structures(team)
  if not Entity or not Entity.GetBuildings then
    return {}
  end
  return Entity.GetBuildings(team)
end

function api.get_spell_cooldown(entity, ability)
  if not entity or not ability or not Ability or not Ability.GetCooldown then
    return math.huge
  end
  return Ability.GetCooldown(ability)
end

function api.get_ability_by_name(entity, name)
  if not entity or not NPC or not NPC.GetAbilityByName then
    return nil
  end
  return NPC.GetAbilityByName(entity, name)
end

function api.estimate_spell_damage(entity, name)
  local ability = api.get_ability_by_name(entity, name)
  if not ability then
    return 0
  end
  if Ability and Ability.GetLevelSpecialValueFor then
    local level = Ability.GetLevel(ability)
    if level > 0 then
      return Ability.GetLevelSpecialValueFor(ability, "damage", level) or 0
    end
  end
  if Ability and Ability.GetDamage then
    return Ability.GetDamage(ability)
  end
  return 0
end

function api.can_cast_ability(entity, ability)
  if not entity or not ability or not Ability then
    return false
  end
  if not Ability.IsCastable or not Ability.IsReady then
    return false
  end
  return Ability.IsCastable(ability) and Ability.IsReady(ability)
end

function api.cast_ability_on_target(player, ability, target)
  if not player or not ability or not target or not Player or not Player.PrepareUnitOrders then
    return false
  end
  Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, target, nil, ability, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, api.get_local_hero(), false, true)
  return true
end

function api.cast_ability_on_position(player, ability, position)
  if not player or not ability or not position or not Player or not Player.PrepareUnitOrders then
    return false
  end
  Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, Vector(position.x, position.y, position.z or 0), ability, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, api.get_local_hero(), false, true)
  return true
end

function api.attack_target(player, target)
  if not player or not target or not Player or not Player.PrepareUnitOrders then
    return false
  end
  Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, target, nil, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, api.get_local_hero(), false, true)
  return true
end

function api.move_to_position(player, position)
  if not player or not Player or not Player.PrepareUnitOrders or not position then
    return false
  end
  Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, Vector(position.x, position.y, position.z or 0), nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, api.get_local_hero(), false, true)
  return true
end

function api.hold_position(player)
  if not player or not Player or not Player.PrepareUnitOrders then
    return false
  end
  Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION, nil, nil, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, api.get_local_hero(), false, true)
  return true
end

function api.stop(player)
  if not player or not Player or not Player.PrepareUnitOrders then
    return false
  end
  Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, nil, nil, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, api.get_local_hero(), false, true)
  return true
end

function api.find_path(start_pos, end_pos)
  if not start_pos or not end_pos or not GridNav or not GridNav.Pathfinder then
    return { end_pos }
  end
  local nodes = GridNav.Pathfinder(start_pos, end_pos)
  if not nodes or #nodes == 0 then
    return { end_pos }
  end
  return nodes
end

function api.in_danger_zone(position)
  if not position or not GridNav or not GridNav.IsBlocked then
    return false
  end
  return GridNav.IsBlocked(Vector(position.x, position.y, position.z or 0))
end

function api.register_event(name, handler)
  if Engine and Engine.On then
    Engine.On(name, handler)
  end
end

function api.on(event, callback)
  api.register_event(event, callback)
end

return api
