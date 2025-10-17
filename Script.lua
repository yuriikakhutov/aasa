---@diagnostic disable: undefined-global, param-type-mismatch, assign-type-mismatch

--[[
    UCZone auto-pilot for Dota 2 heroes.
    The controller plays with the most aggressive settings available in the cheat
    and constantly evaluates combat and defensive situations to mimic the
    behaviour of the hardest vanilla bot difficulty.

    The implementation is deliberately generic so it can control any hero.  It
    uses ability metadata to guess how spells should be fired and keeps a small
    amount of persistent state to build combos, manage mobility and retreat when
    a fight becomes unwinnable.
--]]

local autopilot = {}

--#region menu
local menu_root = Menu.Create("AI", "Automation", "UCZone", "Autopilot")
local general_group = menu_root:Create("General")
local combat_group = menu_root:Create("Combat")
local defense_group = menu_root:Create("Defense")
local macro_group = menu_root:Create("Macro")
local ally_group = menu_root:Create("Controlled Units")

local ui = {
    enable = general_group:Switch("Enable autopilot", true),
    hardcore = general_group:Switch("Hardcore mode (max difficulty)", true),
    debug = general_group:Switch("Print debug notifications", false),

    use_spells = combat_group:Switch("Use hero abilities", true),
    use_items = combat_group:Switch("Use offensive items", true),
    mobility_items = combat_group:Switch("Use mobility items", true),
    target_radius = combat_group:Slider("Enemy scan radius", 1400, 400, 2600, "%.0f"),
    low_hp_bonus = combat_group:Slider("Low HP focus bonus", 325, 0, 600, "%.0f"),
    combo_window = combat_group:Slider("Combo window (sec)", 2.75, 0.5, 6.0, "%.2f"),

    defensive_items = defense_group:Switch("Use defensive items", true),
    healing_items = defense_group:Switch("Consume regen items", true),
    panic_threshold = defense_group:Slider("Panic HP threshold %", 38, 5, 75, "%.0f%%"),
    panic_density = defense_group:Slider("Enemies around to panic", 2, 1, 5, "%.0f"),

    follow_lane = macro_group:Switch("Follow allied lane creeps", true),
    farm_neutrals = macro_group:Switch("Farm neutral camps", true),
    push_structures = macro_group:Switch("Push structures when safe", true),

    control_allies = ally_group:Switch("Control dominated/illusion units", true),
    unit_interval = ally_group:Slider("Unit command interval (ms)", 550, 200, 2000, "%.0f"),
}
--#endregion

--#region state
local state = {
    hero = nil,
    player = nil,
    team = nil,
    last_refresh = 0,
    next_move_time = 0,
    next_attack_time = 0,
    next_unit_tick = 0,
    current_target = nil,
    current_destination = nil,
    last_move_stamp = 0,
    last_move_distance = 0,
    ability_locks = {},
    panic_until = 0,
    idle_anchor = nil,
}

local const = {
    refresh_delay = 0.30,
    ability_buffer = 0.25,
    hero_idle_radius = 2100,
    neutral_radius = 3200,
    structure_radius = 3200,
    follow_distance = 525,
    unit_attack_buffer = 0.1,
    fountain = {
        [Enum.TeamNum.TEAM_RADIANT] = Vector(-7093.0, -6535.0, 256.0),
        [Enum.TeamNum.TEAM_DIRE] = Vector(7046.0, 6480.0, 256.0),
    },
    defensive = {
        item_black_king_bar = { behaviour = "no_target", panic_only = true },
        item_blade_mail = { behaviour = "no_target", panic_only = false },
        item_guardian_greaves = { behaviour = "no_target", panic_only = false },
        item_pipe = { behaviour = "no_target", panic_only = false },
        item_crimson_guard = { behaviour = "no_target", panic_only = false },
        item_manta = { behaviour = "no_target", panic_only = true },
        item_satanic = { behaviour = "no_target", panic_only = true },
        item_lotus_orb = { behaviour = "ally_target", panic_only = true },
        item_glimmer_cape = { behaviour = "ally_target", panic_only = true },
        item_ghost = { behaviour = "no_target", panic_only = true },
        item_eternal_shroud = { behaviour = "no_target", panic_only = true },
        item_bloodstone = { behaviour = "no_target", panic_only = true },
    },
    healing = {
        item_magic_wand = { behaviour = "no_target" },
        item_magic_stick = { behaviour = "no_target" },
        item_flask = { behaviour = "ally_target" },
        item_clarity = { behaviour = "ally_target" },
        item_enchanted_mango = { behaviour = "ally_target" },
    },
    mobility = {
        item_blink = { behaviour = "point", min_range = 550, max_range = 1200 },
        item_overwhelming_blink = { behaviour = "point", min_range = 550, max_range = 1200 },
        item_swift_blink = { behaviour = "point", min_range = 550, max_range = 1200 },
        item_arcane_blink = { behaviour = "point", min_range = 550, max_range = 1200 },
        item_force_staff = { behaviour = "ally_target" },
        item_hurricane_pike = { behaviour = "ally_target" },
        item_cyclone = { behaviour = "enemy_target" },
    },
}
--#endregion

--#region helpers
local function debug(msg)
    if not ui.debug:Get() then
        return
    end
    Log.Write("[autopilot] " .. tostring(msg))
end

local function reset_transient_state()
    state.next_move_time = 0
    state.next_attack_time = 0
    state.current_target = nil
    state.current_destination = nil
    state.ability_locks = {}
    state.panic_until = 0
end

local function hero_position()
    if not state.hero then
        return Vector()
    end
    return Entity.GetAbsOrigin(state.hero)
end

local function dist2d(a, b)
    return (a - b):Length2D()
end

local function has_behavior(mask, flag)
    if not mask then
        return false
    end
    return (mask & flag) ~= 0
end

local function ability_identifier(ability)
    local index = Ability.GetIndex(ability)
    if index and index >= 0 then
        return index
    end
    return Ability.GetName(ability)
end

local function can_issue_move()
    return GameRules.GetGameTime() >= state.next_move_time
end

local function can_issue_attack()
    return GameRules.GetGameTime() >= state.next_attack_time
end

local function schedule_move(delay)
    state.next_move_time = GameRules.GetGameTime() + (delay or 0.05)
end

local function schedule_attack(delay)
    state.next_attack_time = GameRules.GetGameTime() + (delay or const.unit_attack_buffer)
end

local function lock_ability(ability, extra)
    if not ability then return end
    state.ability_locks[ability_identifier(ability)] = GameRules.GetGameTime() + (extra or const.ability_buffer)
end

local function is_ability_locked(ability)
    if not ability then return false end
    local key = ability_identifier(ability)
    local lock = state.ability_locks[key]
    return lock ~= nil and lock > GameRules.GetGameTime()
end

local function is_valid_enemy(target)
    if not target or not Entity.IsAlive(target) then
        return false
    end
    if Entity.IsDormant(target) or Entity.IsInvulnerable(target) then
        return false
    end
    if NPC.IsIllusion(target) and not Entity.IsHero(target) then
        return false
    end
    return true
end

local function get_cast_range_bonus(hero)
    local bonus = NPC.GetCastRangeBonus(hero) or 0
    if ui.hardcore:Get() then
        bonus = bonus + 35 -- small extra buffer in hardcore mode
    end
    return bonus
end

local function hero_attack_range(hero)
    return NPC.GetAttackRange(hero) + NPC.GetHullRadius(hero) + 50
end
--#endregion

--#region ability helpers
local function ability_cast_type(ability)
    local behavior = Ability.GetBehavior(ability)
    if not behavior then
        return nil
    end
    if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_PASSIVE) then
        return nil
    end
    if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
        return "target"
    end
    if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) then
        return "point"
    end
    if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
        return "no_target"
    end
    return nil
end

local function ability_ready(hero, ability)
    if not ability or Ability.IsHidden(ability) or Ability.IsPassive(ability) then
        return false
    end
    if Ability.GetLevel(ability) <= 0 then
        return false
    end
    if Ability.IsChannelling(ability) then
        return false
    end
    if not Ability.IsCastable(ability, NPC.GetMana(hero)) then
        return false
    end
    if is_ability_locked(ability) then
        return false
    end
    if NPC.IsStunned(hero) or NPC.IsSilenced(hero) or (NPC.IsMuted and NPC.IsMuted(hero)) then
        return false
    end
    return true
end

local function cast_with_type(hero, ability, target, forced_type)
    local behavior_type = forced_type or ability_cast_type(ability)
    if not behavior_type then
        return false
    end
    local hero_pos = Entity.GetAbsOrigin(hero)
    local bonus = get_cast_range_bonus(hero)
    local cast_range = Ability.GetCastRange(ability) or 0

    if behavior_type == "target" then
        if not target or not is_valid_enemy(target) then
            return false
        end
        local dist = dist2d(hero_pos, Entity.GetAbsOrigin(target))
        if cast_range > 0 and dist > cast_range + bonus + 100 then
            return false
        end
        Ability.CastTarget(ability, target, false, false, true, "ucz_autopilot")
        return true
    end

    if behavior_type == "point" then
        local point
        if target then
            point = Entity.GetAbsOrigin(target)
        elseif state.current_destination then
            point = state.current_destination
        else
            return false
        end
        local dist = dist2d(hero_pos, point)
        if cast_range > 0 and dist > cast_range + bonus + 100 then
            return false
        end
        Ability.CastPosition(ability, point, false, false, true, "ucz_autopilot", true)
        return true
    end

    if behavior_type == "no_target" then
        Ability.CastNoTarget(ability, false, false, true, "ucz_autopilot")
        return true
    end

    return false
end

local function use_ability(hero, ability, target)
    if not ui.use_spells:Get() then
        return false
    end
    if not ability_ready(hero, ability) then
        return false
    end
    if cast_with_type(hero, ability, target, nil) then
        lock_ability(ability, ui.combo_window:Get())
        return true
    end
    return false
end

local function fire_combat_spells(hero, target)
    if not ui.use_spells:Get() then
        return false
    end

    for slot = 0, NPC.GetAbilityCount(hero) - 1 do
        local ability = NPC.GetAbilityByIndex(hero, slot)
        if use_ability(hero, ability, target) then
            return true
        end
    end
    return false
end
--#endregion

--#region item helpers
local function cast_item(hero, item, target, config)
    local behavior = Ability.GetBehavior(item)
    local cast_range = Ability.GetCastRange(item) or 0
    local hero_pos = Entity.GetAbsOrigin(hero)
    local bonus = get_cast_range_bonus(hero)
    local item_type = ability_cast_type(item)

    if config and config.behaviour then
        item_type = config.behaviour
    end

    if item_type == "ally_target" then
        target = hero
    end

    if item_type == "enemy_target" then
        if not target or not is_valid_enemy(target) then
            return false
        end
    end

    if item_type == "point" then
        local point
        if target then
            point = Entity.GetAbsOrigin(target)
        elseif state.current_destination then
            point = state.current_destination
        else
            return false
        end
        local dist = dist2d(hero_pos, point)
        if cast_range > 0 and dist > cast_range + bonus + 150 then
            return false
        end
        -- reposition to chase or escape
        Ability.CastPosition(item, point, false, false, true, "ucz_autopilot", true)
        return true
    end

    if item_type == "target" or item_type == "enemy_target" then
        local point = target and Entity.GetAbsOrigin(target)
        if not point then return false end
        local dist = dist2d(hero_pos, point)
        if cast_range > 0 and dist > cast_range + bonus + 100 then
            return false
        end
        Ability.CastTarget(item, target, false, false, true, "ucz_autopilot")
        return true
    end

    if item_type == "no_target" or item_type == "ally_target" then
        Ability.CastNoTarget(item, false, false, true, "ucz_autopilot")
        return true
    end

    return false
end

local function iterate_inventory(hero, func)
    for slot = 0, 16 do
        local item = NPC.GetItemByIndex(hero, slot)
        if item then
            func(item)
        end
    end
end

local function use_item_table(hero, target, table_config, opts)
    local used = false
    iterate_inventory(hero, function(item)
        if used then return end
        local name = Ability.GetName(item)
        local config = table_config[name]
        if not config then return end
        if not Ability.IsCastable(item, NPC.GetMana(hero)) then return end
        if Ability.IsChannelling(item) then return end
        if is_ability_locked(item) then return end
        if opts and opts.panic_only and not config.panic_only then return end

        if cast_item(hero, item, target, config) then
            used = true
            lock_ability(item, opts and opts.buffer or const.ability_buffer)
        end
    end)
    return used
end

local function use_offensive_items(hero, target)
    if not ui.use_items:Get() or not target then
        return false
    end

    local used = false
    iterate_inventory(hero, function(item)
        if used then return end
        if not Ability.IsCastable(item, NPC.GetMana(hero)) then return end
        if Ability.IsChannelling(item) or Ability.IsPassive(item) then return end
        if is_ability_locked(item) then return end

        local behavior = Ability.GetBehavior(item)
        if not behavior or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_PASSIVE) then
            return
        end

        if cast_item(hero, item, target, nil) then
            used = true
            lock_ability(item, const.ability_buffer)
        end
    end)
    return used
end

local function use_mobility(hero, target, threat_state)
    if not ui.mobility_items:Get() then
        return false
    end

    local used = false
    iterate_inventory(hero, function(item)
        if used then return end
        local name = Ability.GetName(item)
        local config = const.mobility[name]
        if not config then return end
        if not Ability.IsCastable(item, NPC.GetMana(hero)) then return end
        if is_ability_locked(item) then return end

        if config.behaviour == "point" then
            local dest
            if threat_state and threat_state.mode == "escape" then
                dest = state.idle_anchor or const.fountain[state.team] or hero_position()
            elseif target then
                local hero_pos = hero_position()
                local target_pos = Entity.GetAbsOrigin(target)
                local direction = (target_pos - hero_pos):Normalized()
                local distance = dist2d(hero_pos, target_pos)
                local length = math.min(distance - hero_attack_range(hero), config.max_range or 1200)
                length = math.max(length, config.min_range or 600)
                dest = hero_pos + direction * length
            end
            if dest then
                Ability.CastPosition(item, dest, false, false, true, "ucz_autopilot", true)
                used = true
                lock_ability(item, 1.0)
            end
        elseif config.behaviour == "ally_target" then
            Ability.CastTarget(item, state.hero, false, false, true, "ucz_autopilot")
            used = true
            lock_ability(item, 0.5)
        elseif config.behaviour == "enemy_target" and target then
            Ability.CastTarget(item, target, false, false, true, "ucz_autopilot")
            used = true
            lock_ability(item, 0.5)
        end
    end)
    return used
end

local function use_defensive(hero, threat_state)
    if not ui.defensive_items:Get() then
        return false
    end

    local panic = threat_state and threat_state.mode == "escape"
    local used = false
    iterate_inventory(hero, function(item)
        if used then return end
        local name = Ability.GetName(item)
        local config = const.defensive[name]
        if not config then return end
        if config.panic_only and not panic then return end
        if not Ability.IsCastable(item, NPC.GetMana(hero)) then return end
        if is_ability_locked(item) then return end

        if cast_item(hero, item, state.current_target, config) then
            used = true
            lock_ability(item, 0.5)
        end
    end)
    return used
end

local function use_healing(hero)
    if not ui.healing_items:Get() then
        return false
    end

    if Entity.GetHealth(hero) / math.max(Entity.GetMaxHealth(hero), 1) > 0.85 then
        return false
    end

    local used = false
    iterate_inventory(hero, function(item)
        if used then return end
        local name = Ability.GetName(item)
        local config = const.healing[name]
        if not config then return end
        if not Ability.IsCastable(item, NPC.GetMana(hero)) then return end
        if is_ability_locked(item) then return end
        if cast_item(hero, item, state.hero, config) then
            used = true
            lock_ability(item, 0.5)
        end
    end)
    return used
end
--#endregion

--#region targeting & environment
local function count_enemies(hero, radius)
    local heroes = Entity.GetHeroesInRadius(hero, radius, Enum.TeamType.TEAM_ENEMY, true, true)
    local count, total_hp = 0, 0
    for _, enemy in ipairs(heroes) do
        if is_valid_enemy(enemy) then
            count = count + 1
            total_hp = total_hp + math.max(Entity.GetHealth(enemy), 1)
        end
    end
    return count, total_hp
end

local function evaluate_threat(hero)
    local hp = Entity.GetHealth(hero)
    local max_hp = math.max(Entity.GetMaxHealth(hero), 1)
    local hp_pct = hp / max_hp
    local enemy_count, enemy_hp = count_enemies(hero, 900)
    local melee_count = 0
    local melee_units = Entity.GetUnitsInRadius(hero, 500, Enum.TeamType.TEAM_ENEMY, true, true)
    for _, unit in ipairs(melee_units) do
        if is_valid_enemy(unit) and NPC.IsHero(unit) then
            melee_count = melee_count + 1
        end
    end

    local threat = enemy_count * 1.5 + melee_count
    if hp_pct < 0.45 then
        threat = threat + (0.45 - hp_pct) * 4.0
    end

    local level = "low"
    if threat >= 3.5 or hp_pct * 100 <= ui.panic_threshold:Get() then
        level = "high"
    elseif threat >= 1.75 then
        level = "medium"
    end

    return {
        level = level,
        hp_pct = hp_pct,
        enemies = enemy_count,
        total_hp = enemy_hp,
        threat_score = threat,
        mode = level == "high" and "escape" or "fight",
    }
end

local function select_target(hero)
    local radius = ui.target_radius:Get()
    local my_pos = Entity.GetAbsOrigin(hero)
    local best, best_score = nil, math.huge
    local illusions, illusion_score = nil, math.huge

    local candidates = Entity.GetHeroesInRadius(hero, radius, Enum.TeamType.TEAM_ENEMY, true, true)
    for _, enemy in ipairs(candidates) do
        if is_valid_enemy(enemy) then
            local pos = Entity.GetAbsOrigin(enemy)
            local dist = dist2d(my_pos, pos)
            local hp_ratio = Entity.GetHealth(enemy) / math.max(Entity.GetMaxHealth(enemy), 1)
            local score = dist
            score = score + hp_ratio * ui.low_hp_bonus:Get()
            if NPC.IsChannellingAbility(enemy) then
                score = score - 200
            end
            if NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
                score = score + 100
            end
            if NPC.IsIllusion(enemy) then
                if score < illusion_score then
                    illusion_score = score + 50
                    illusions = enemy
                end
            elseif score < best_score then
                best_score = score
                best = enemy
            end
        end
    end

    if best then return best end
    if illusions then return illusions end

    local creeps = Entity.GetUnitsInRadius(hero, 900, Enum.TeamType.TEAM_ENEMY, true, true)
    local best_creep, best_creep_score = nil, math.huge
    for _, creep in ipairs(creeps) do
        if NPC.IsCreep(creep) and Entity.IsAlive(creep) then
            local score = dist2d(my_pos, Entity.GetAbsOrigin(creep))
            if score < best_creep_score then
                best_creep_score = score
                best_creep = creep
            end
        end
    end
    return best_creep
end

local function find_lane_anchor(hero)
    if not ui.follow_lane:Get() then
        return nil
    end
    local units = Entity.GetUnitsInRadius(hero, 1600, Enum.TeamType.TEAM_FRIEND, true, true)
    local my_pos = Entity.GetAbsOrigin(hero)
    local best, best_distance = nil, math.huge
    for _, unit in ipairs(units) do
        if unit ~= hero and NPC.IsLaneCreep(unit) and Entity.IsAlive(unit) then
            local dist = dist2d(my_pos, Entity.GetAbsOrigin(unit))
            if dist < best_distance then
                best_distance = dist
                best = unit
            end
        end
    end
    return best and Entity.GetAbsOrigin(best) or nil
end

local function find_neutral(hero)
    if not ui.farm_neutrals:Get() then
        return nil
    end
    local units = Entity.GetUnitsInRadius(hero, const.neutral_radius, Enum.TeamType.TEAM_NEUTRAL, true, true)
    local my_pos = Entity.GetAbsOrigin(hero)
    local best, best_score = nil, math.huge
    for _, unit in ipairs(units) do
        if NPC.IsCreep(unit) and Entity.IsAlive(unit) then
            local score = dist2d(my_pos, Entity.GetAbsOrigin(unit))
            if score < best_score then
                best_score = score
                best = unit
            end
        end
    end
    return best
end

local function find_structure(hero)
    if not ui.push_structures:Get() then
        return nil
    end
    local structures = Entity.GetUnitsInRadius(hero, const.structure_radius, Enum.TeamType.TEAM_ENEMY, true, true)
    local my_pos = Entity.GetAbsOrigin(hero)
    local best, best_score = nil, math.huge
    for _, structure in ipairs(structures) do
        if Entity.IsAlive(structure) and (NPC.IsTower(structure) or NPC.IsBarracks(structure) or NPC.IsFort(structure)) then
            local score = dist2d(my_pos, Entity.GetAbsOrigin(structure))
            if score < best_score then
                best_score = score
                best = structure
            end
        end
    end
    return best
end

--#endregion

--#region movement & orders
local function move_to(hero, player, position, options)
    if not position or not can_issue_move() then
        return
    end

    local now = GameRules.GetGameTime()
    local hero_pos = Entity.GetAbsOrigin(hero)
    local distance = dist2d(hero_pos, position)

    if state.current_destination and distance < 100 then
        local same = dist2d(state.current_destination, position) < 80
        if same and now - state.last_move_stamp < 0.5 then
            return
        end
    end

    local direct = options and options.direct
    local order = direct and Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION or Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE

    Player.PrepareUnitOrders(
        player,
        order,
        nil,
        position,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        hero,
        false,
        false,
        false,
        true,
        "ucz_autopilot"
    )

    state.current_destination = position
    state.last_move_stamp = now
    state.last_move_distance = distance
    schedule_move((ui.hardcore:Get() and 0.18 or ui.unit_interval:Get() / 1000.0))
end

local function attack_target(hero, player, target)
    if not target or not is_valid_enemy(target) then
        return
    end
    if not can_issue_attack() then
        return
    end
    Player.AttackTarget(player, hero, target, false, false, true, "ucz_autopilot", true)
    state.current_target = target
    state.current_destination = nil
    schedule_attack(0.05)
end

local function control_allies(hero, player, target)
    if not ui.control_allies:Get() then
        return
    end
    local now = GameRules.GetGameTime()
    if now < state.next_unit_tick then
        return
    end
    state.next_unit_tick = now + ui.unit_interval:Get() / 1000.0

    local player_id = Players.GetPlayerID(player)
    local units = Entity.GetUnitsInRadius(hero, 2500, Enum.TeamType.TEAM_FRIEND, true, true)
    local dest = state.current_destination or hero_position()

    for _, unit in ipairs(units) do
        if unit ~= hero and Entity.IsAlive(unit) and NPC.IsControllableByPlayer(unit, player_id) then
            if target and is_valid_enemy(target) and dist2d(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(target)) <= 900 then
                Player.AttackTarget(player, unit, target, false, false, true, "ucz_autopilot_units", true)
            else
                Player.PrepareUnitOrders(
                    player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                    nil,
                    dest,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    unit,
                    false,
                    false,
                    false,
                    true,
                    "ucz_autopilot_units"
                )
            end
        end
    end
end
--#endregion

--#region behaviour
local function update_idle_anchor()
    state.idle_anchor = find_lane_anchor(state.hero) or hero_position()
end

local function compute_behaviour(hero, player)
    local threat = evaluate_threat(hero)
    if threat.level == "high" then
        state.panic_until = GameRules.GetGameTime() + 1.25
    end

    local target = select_target(hero)
    state.current_target = target

    if GameRules.GetGameTime() < state.panic_until then
        threat.mode = "escape"
    end

    if threat.mode == "escape" then
        use_defensive(hero, threat)
        use_mobility(hero, target, threat)
        use_healing(hero)
        local anchor = state.idle_anchor or const.fountain[state.team]
        move_to(hero, player, anchor or hero_position(), { direct = true })
        return
    end

    if target and is_valid_enemy(target) then
        use_mobility(hero, target, threat)
        if ui.hardcore:Get() then
            fire_combat_spells(hero, target)
            use_offensive_items(hero, target)
        else
            use_offensive_items(hero, target)
            fire_combat_spells(hero, target)
        end
        attack_target(hero, player, target)
        control_allies(hero, player, target)
        return
    end

    local neutral = find_neutral(hero)
    if neutral then
        attack_target(hero, player, neutral)
        return
    end

    local structure = find_structure(hero)
    if structure then
        move_to(hero, player, Entity.GetAbsOrigin(structure), { direct = false })
        return
    end

    update_idle_anchor()
    move_to(hero, player, state.idle_anchor, { direct = false })
end
--#endregion

--#region callbacks
local function refresh_handles()
    local me = Heroes.GetLocal()
    if not me then
        return false
    end
    state.hero = me
    state.player = Players.GetLocal()
    state.team = Entity.GetTeamNum(me)
    return true
end

function autopilot.OnUpdate()
    if not Engine.IsInGame() or not ui.enable:Get() then
        return
    end
    if not state.hero or not Entity.IsAlive(state.hero) then
        if GameRules.GetGameTime() > state.last_refresh + const.refresh_delay then
            refresh_handles()
            state.last_refresh = GameRules.GetGameTime()
        end
        return
    end

    local now = GameRules.GetGameTime()
    if now - state.last_refresh > const.refresh_delay then
        update_idle_anchor()
        state.last_refresh = now
    end

    compute_behaviour(state.hero, state.player)
end

function autopilot.OnGameStart()
    refresh_handles()
    reset_transient_state()
end

function autopilot.OnGameEnd()
    reset_transient_state()
end

function autopilot.OnScriptLoad()
    refresh_handles()
    reset_transient_state()
end

function autopilot.OnScriptUnload()
    reset_transient_state()
end
--#endregion

return autopilot
