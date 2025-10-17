---@diagnostic disable: undefined-global, param-type-mismatch

--[[
    OpenHyperAI-inspired autopilot for Dota 2 (UCZone scripting environment).
    Automatically handles combat and farming cycles so the hero can play on its own.
    The implementation aims to mirror the OpenHyperAI feature-set while still being
    generic enough to pilot any hero.  The controller evaluates the situation around
    the hero every frame and reacts with aggressive, defensive and farming behaviours
    to keep pressure on the map without player input.

    Links and credits:
    * OpenHyperAI: https://github.com/forest0xia/dota2bot-OpenHyperAI
--]]

local autoplay = {}

--#region menu setup
local root_tab = Menu.Create("AI", "Automation", "OpenHyperAI", "Controller")
local general_group = root_tab:Create("General")
local combat_group = root_tab:Create("Combat")
local defense_group = root_tab:Create("Defense")
local movement_group = root_tab:Create("Movement")
local farming_group = root_tab:Create("Macro / Farming")
local units_group = root_tab:Create("Controlled Units")

local ui = {
    enabled = general_group:Switch("Enable OpenHyperAI autopilot", true),
    debug = general_group:Switch("Show debug notifications", false),

    use_spells = combat_group:Switch("Use abilities automatically", true),
    use_items = combat_group:Switch("Use offensive items", true),
    use_mobility_items = combat_group:Switch("Use mobility items to chase", true),
    target_radius = combat_group:Slider("Enemy search radius", 1200, 400, 2500, "%.0f"),
    focus_low_hp = combat_group:Slider("Bonus weight for low HP targets", 200, 0, 400, "%.0f"),
    combo_window = combat_group:Slider("Spell combo window (s)", 2.5, 0.5, 6.0, "%.1f"),

    use_defensive_items = defense_group:Switch("Use defensive items automatically", true),
    use_healing_items = defense_group:Switch("Consume regen when safe", true),
    panic_threshold = defense_group:Slider("Emergency panic threshold (%)", 35, 5, 70, "%.0f%%"),
    enemy_density_threshold = defense_group:Slider("Enemy density panic (heroes)", 2, 1, 5, "%.0f"),

    retreat = movement_group:Switch("Retreat when health is low", true),
    retreat_threshold = movement_group:Slider("Retreat threshold (%)", 25, 5, 60, "%.0f%%"),
    follow_lane_creeps = movement_group:Switch("Follow allied lane creeps", true),
    kite_melee = movement_group:Switch("Kite melee enemies", true),
    move_interval = movement_group:Slider("Move order interval (ms)", 280, 120, 900, "%.0f"),

    farm_neutrals = farming_group:Switch("Farm nearby neutral camps", true),
    push_structures = farming_group:Switch("Siege enemy structures when safe", true),
    rune_hunt = farming_group:Switch("Collect runes when idle", true),

    control_allies = units_group:Switch("Command controllable allies", true),
    illusion_split = units_group:Switch("Split push with illusions", true),
    unit_update_interval = units_group:Slider("Controlled unit order interval (ms)", 600, 200, 2000, "%.0f"),
}
--#endregion

--#region state
local state = {
    hero = nil,
    player = nil,
    team = nil,
    last_update = 0,
    next_move_time = 0,
    next_attack_time = 0,
    next_unit_command = 0,
    current_target = nil,
    current_move_position = nil,
    current_move_time = 0,
    current_move_distance = nil,
    idle_position = nil,
    ability_cooldowns = {},
    combo_window = {},
    last_threat_level = "low",
}

local const = {
    fallback_radius = 900.0,
    ability_buffer = 0.25,
    threat_radius = 900.0,
    threat_refresh = 0.25,
    neutral_scan_radius = 3200.0,
    rune_scan_radius = 2500.0,
    structure_scan_radius = 3200.0,
    kiting_distance = 425.0,
    base_positions = {
        [Enum.TeamNum.TEAM_RADIANT] = Vector(-7093.0, -6535.0, 256.0),
        [Enum.TeamNum.TEAM_DIRE] = Vector(7046.0, 6480.0, 256.0),
    },
    objective_names = {
        "dota_badguys_tower1_top", "dota_badguys_tower1_mid", "dota_badguys_tower1_bot",
        "dota_goodguys_tower1_top", "dota_goodguys_tower1_mid", "dota_goodguys_tower1_bot",
    },
    defensive_items = {
        item_black_king_bar = { behavior = "no_target", panic_only = true },
        item_blade_mail = { behavior = "no_target", panic_only = false },
        item_crimson_guard = { behavior = "no_target", panic_only = false },
        item_pipe = { behavior = "no_target", panic_only = false },
        item_guardian_greaves = { behavior = "no_target", panic_only = false },
        item_phase_boots = { behavior = "no_target", panic_only = false, move_speed = true },
        item_ghost = { behavior = "no_target", panic_only = true },
        item_glimmer_cape = { behavior = "ally_target", panic_only = true },
        item_lotus_orb = { behavior = "ally_target", panic_only = true },
        item_manta = { behavior = "no_target", panic_only = true },
        item_satanic = { behavior = "no_target", panic_only = true },
        item_eternal_shroud = { behavior = "no_target", panic_only = false },
        item_bloodstone = { behavior = "no_target", panic_only = true },
    },
    mobility_items = {
        item_blink = { behavior = "point", min_distance = 600, max_distance = 1150 },
        item_overwhelming_blink = { behavior = "point", min_distance = 600, max_distance = 1200 },
        item_swift_blink = { behavior = "point", min_distance = 600, max_distance = 1200 },
        item_arcane_blink = { behavior = "point", min_distance = 600, max_distance = 1200 },
        item_force_staff = { behavior = "ally_target" },
        item_hurricane_pike = { behavior = "ally_target" },
        item_cyclone = { behavior = "enemy_target", chase_only = true },
    },
    healing_items = {
        item_magic_stick = { behavior = "no_target" },
        item_magic_wand = { behavior = "no_target" },
        item_soul_ring = { behavior = "no_target" },
        item_greater_faerie_fire = { behavior = "no_target" },
        item_bottle = { behavior = "no_target" },
        item_clarity = { behavior = "ally_target", self_only = true, requires_safety = true },
        item_flask = { behavior = "ally_target", self_only = true, requires_safety = true },
    },
}
--#endregion

--#region helpers
local function reset_state()
    state.hero = nil
    state.player = nil
    state.team = nil
    state.last_update = 0
    state.next_move_time = 0
    state.next_attack_time = 0
    state.next_unit_command = 0
    state.current_target = nil
    state.current_move_position = nil
    state.current_move_time = 0
    state.current_move_distance = nil
    state.idle_position = nil
    state.ability_cooldowns = {}
    state.combo_window = {}
    state.last_threat_level = "low"
end

local function refresh_handles()
    if not state.player then
        state.player = Players.GetLocal()
    end
    if not state.hero then
        state.hero = Heroes.GetLocal()
        if state.hero then
            state.team = Entity.GetTeamNum(state.hero)
        end
    end
    return state.player ~= nil and state.hero ~= nil
end

local function debug(message)
    if not ui.debug:Get() then
        return
    end
    Notifications.AddBottom(message, 2.0)
end

local function can_issue_move()
    local now = GameRules.GetGameTime()
    return now >= state.next_move_time
end

local function mark_move(delay)
    local now = GameRules.GetGameTime()
    state.next_move_time = now + delay
end

local function can_issue_attack()
    local now = GameRules.GetGameTime()
    return now >= state.next_attack_time
end

local function mark_attack(delay)
    local now = GameRules.GetGameTime()
    state.next_attack_time = now + delay
end

local function can_issue_unit_command()
    local now = GameRules.GetGameTime()
    return now >= state.next_unit_command
end

local function mark_unit_command(delay)
    local now = GameRules.GetGameTime()
    state.next_unit_command = now + delay
end

local function distance2d(a, b)
    return (a - b):Length2D()
end

local function has_behavior(ability_behavior, behavior)
    if not ability_behavior or not behavior then return false end
    return (ability_behavior & behavior) ~= 0
end

local function is_valid_target(target)
    if not target or not Entity.IsAlive(target) or Entity.IsDormant(target) then
        return false
    end
    if Entity.IsInvulnerable(target) then
        return false
    end
    if NPC.IsAttackImmune(target) then
        return false
    end
    return true
end

local function get_attack_range(hero)
    return NPC.GetAttackRange(hero) + NPC.GetHullRadius(hero) + 25
end

local function count_enemies(hero, radius)
    local enemies = Entity.GetHeroesInRadius(hero, radius, Enum.TeamType.TEAM_ENEMY, true, true)
    local count, total_health = 0, 0
    for i = 1, #enemies do
        local enemy = enemies[i]
        if is_valid_target(enemy) then
            count = count + 1
            total_health = total_health + math.max(Entity.GetHealth(enemy), 0)
        end
    end
    return count, total_health
end

local function evaluate_threat(hero)
    local hp = Entity.GetHealth(hero)
    local max_hp = math.max(Entity.GetMaxHealth(hero), 1)
    local hp_pct = hp / max_hp
    local enemy_count, enemy_health = count_enemies(hero, const.threat_radius)
    local melee_threat = Entity.GetUnitsInRadius(hero, 450, Enum.TeamType.TEAM_ENEMY, true, true)
    local melee_count = 0
    for i = 1, #melee_threat do
        local unit = melee_threat[i]
        if is_valid_target(unit) and NPC.IsHero(unit) then
            melee_count = melee_count + 1
        end
    end

    local threat_score = enemy_count * 1.5 + melee_count * 0.75
    if hp_pct < 0.4 then
        threat_score = threat_score + (0.4 - hp_pct) * 5
    end

    local level = "low"
    if threat_score >= 3.5 or hp_pct <= ui.panic_threshold:Get() / 100.0 then
        level = "high"
    elseif threat_score >= 1.75 then
        level = "medium"
    end

    state.last_threat_level = level
    return {
        level = level,
        enemy_count = enemy_count,
        enemy_health = enemy_health,
        hp_pct = hp_pct,
        threat_score = threat_score,
    }
end

local function ability_key(ability)
    local index = Ability.GetIndex(ability)
    if index and index >= 0 then
        return index
    end
    return Ability.GetName(ability)
end

local function can_cast_ability(hero, ability, target, opts)
    if not ability then return false end
    if Ability.IsHidden(ability) or Ability.IsPassive(ability) then return false end
    if Ability.GetLevel(ability) <= 0 then return false end
    if not Ability.IsCastable(ability, NPC.GetMana(hero)) then return false end
    if Ability.IsChannelling(ability) then return false end
    local treat_as_item = opts and opts.is_item
    if not treat_as_item and NPC.IsSilenced(hero) then return false end
    if NPC.IsStunned(hero) then return false end
    if NPC.IsMuted and NPC.IsMuted(hero) then return false end

    local key = ability_key(ability)
    local next_allowed = state.ability_cooldowns[key]
    if next_allowed and next_allowed > GameRules.GetGameTime() then
        return false
    end

    local behavior = Ability.GetBehavior(ability)
    if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_PASSIVE)
        or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_TOGGLE) then
        return false
    end

    if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
        return target ~= nil and is_valid_target(target)
    end

    return true
end

local function mark_ability_used(ability, buffer)
    local key = ability_key(ability)
    state.ability_cooldowns[key] = GameRules.GetGameTime() + (buffer or const.ability_buffer)
end

local function cast_with_behavior(hero, ability, target, behavior_kind)
    local ability_behavior = Ability.GetBehavior(ability)
    local my_pos = Entity.GetAbsOrigin(hero)
    local target_pos = target and Entity.GetAbsOrigin(target)
    local cast_range = Ability.GetCastRange(ability) or 0
    local bonus = NPC.GetCastRangeBonus(hero)
    local distance_to_target = target_pos and distance2d(my_pos, target_pos) or 0

    if behavior_kind == "ally_target" then
        target = hero
        target_pos = my_pos
    end

    if behavior_kind == "enemy_target" or has_behavior(ability_behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
        if target and is_valid_target(target) then
            if cast_range <= 0 or distance_to_target <= cast_range + bonus + 75 then
                Ability.CastTarget(ability, target, false, false, true, "openhyperai_auto")
                return true
            end
        end
        return false
    end

    if behavior_kind == "point" or has_behavior(ability_behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) then
        if target_pos then
            if cast_range <= 0 or distance_to_target <= cast_range + bonus + 125 then
                Ability.CastPosition(ability, target_pos, false, false, true, "openhyperai_auto", true)
                return true
            end
        end
        return false
    end

    if behavior_kind == "no_target" or has_behavior(ability_behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
        Ability.CastNoTarget(ability, false, false, true, "openhyperai_auto")
        return true
    end

    return false
end

local function use_item_list(hero, target, item_table, opts)
    local used = false
    for slot = 0, 16 do
        local item = NPC.GetItemByIndex(hero, slot)
        if item then
            local name = Ability.GetName(item)
            local config = item_table[name]
            if config and can_cast_ability(hero, item, target, { is_item = true }) then
                if config.panic_only and (not opts or opts.panic_level ~= "high") then
                    goto continue
                end
                if config.requires_safety and opts and opts.check_safety then
                    if not is_position_safe(hero, Entity.GetAbsOrigin(hero)) then
                        goto continue
                    end
                end

                local cast_target = target
                if config.self_only then
                    cast_target = hero
                elseif not cast_target then
                    cast_target = hero
                end

                if cast_with_behavior(hero, item, cast_target, config.behavior) then
                    used = true
                    mark_ability_used(item, const.ability_buffer)
                    if opts and opts.break_after_success then
                        return true
                    end
                end
            end
        end
        ::continue::
    end
    return used
end

local function cast_defensive_items(hero, threat_info)
    if not ui.use_defensive_items:Get() then
        return false
    end

    local panic = threat_info.level == "high"
        or threat_info.enemy_count >= ui.enemy_density_threshold:Get()
        or threat_info.hp_pct <= ui.panic_threshold:Get() / 100.0
    local should_use = panic or threat_info.level ~= "low" or threat_info.hp_pct < 0.65
    if not should_use then
        return false
    end

    return use_item_list(hero, hero, const.defensive_items, {
        panic_level = panic and "high" or threat_info.level,
    })
end

local function cast_healing_items(hero, threat_info)
    if not ui.use_healing_items:Get() then
        return false
    end

    if threat_info.level ~= "low" then
        return false
    end

    local hp_pct = threat_info.hp_pct
    if hp_pct >= 0.95 then
        return false
    end

    return use_item_list(hero, hero, const.healing_items, {
        check_safety = true,
        break_after_success = true,
        panic_level = threat_info.level,
    })
end

local function get_escape_point(hero)
    local hero_pos = Entity.GetAbsOrigin(hero)
    local fountain = get_fountain_position()
    local direction = (fountain - hero_pos)
    if direction:Length2D() == 0 then
        return hero_pos
    end
    direction = direction:Normalized()
    return hero_pos + direction * 900
end

local function cast_mobility_items(hero, target, threat_info)
    if not ui.use_mobility_items:Get() then
        return false
    end

    local hero_pos = Entity.GetAbsOrigin(hero)
    local attack_range = get_attack_range(hero)
    local target_pos = nil
    local distance_to_target = 0
    local chasing = false

    if target and is_valid_target(target) then
        target_pos = Entity.GetAbsOrigin(target)
        distance_to_target = distance2d(hero_pos, target_pos)
        chasing = distance_to_target > attack_range + 100
    end

    local escaping = threat_info.level == "high" or threat_info.hp_pct <= ui.retreat_threshold:Get() / 100.0

    for slot = 0, 16 do
        local item = NPC.GetItemByIndex(hero, slot)
        if item then
            local name = Ability.GetName(item)
            local config = const.mobility_items[name]
            if config and can_cast_ability(hero, item, target or hero, { is_item = true }) then
                if config.chase_only and not chasing then
                    goto continue
                end
                if config.behavior == "point" then
                    local blink_point
                    if escaping then
                        local escape_point = get_escape_point(hero)
                        blink_point = escape_point
                    elseif chasing and target_pos and distance_to_target >= (config.min_distance or 400) then
                        local direction = (target_pos - hero_pos):Normalized()
                        local blink_distance = math.min(distance_to_target - attack_range, config.max_distance or 1150)
                        blink_distance = math.max(blink_distance, config.min_distance or 600)
                        blink_point = hero_pos + direction * blink_distance
                    end
                    if blink_point then
                        Ability.CastPosition(item, blink_point, false, false, true, "openhyperai_gapclose", true)
                        mark_ability_used(item, 1.0)
                        return true
                    end
                elseif config.behavior == "ally_target" then
                    if escaping or chasing then
                        Ability.CastTarget(item, hero, false, false, true, "openhyperai_gapclose")
                        mark_ability_used(item, 0.5)
                        return true
                    end
                elseif config.behavior == "enemy_target" then
                    if chasing and target then
                        Ability.CastTarget(item, target, false, false, true, "openhyperai_gapclose")
                        mark_ability_used(item, 0.5)
                        return true
                    end
                end
            end
        end
        ::continue::
    end

    return false
end

local function select_enemy(hero)
    local radius = ui.target_radius:Get()
    local enemies = Entity.GetHeroesInRadius(hero, radius, Enum.TeamType.TEAM_ENEMY, true, true)
    local my_pos = Entity.GetAbsOrigin(hero)
    local best_target, best_score = nil, math.huge
    local best_illusion, illusion_score = nil, math.huge

    for i = 1, #enemies do
        local enemy = enemies[i]
        if is_valid_target(enemy) then
            local is_illusion = NPC.IsIllusion(enemy)
            local score = distance2d(my_pos, Entity.GetAbsOrigin(enemy))
            local health = Entity.GetHealth(enemy)
            local health_ratio = health / math.max(Entity.GetMaxHealth(enemy), 1)
            score = score + health_ratio * ui.focus_low_hp:Get()
            if NPC.IsChannellingAbility(enemy) then
                score = score - 125
            end
            if NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
                score = score + 75
            end
            if is_illusion then
                if score < illusion_score then
                    illusion_score = score + 75
                    best_illusion = enemy
                end
            elseif score < best_score then
                best_score = score
                best_target = enemy
            end
        end
    end

    if best_target then
        return best_target
    end
    if best_illusion then
        return best_illusion
    end

    local creeps = Entity.GetUnitsInRadius(hero, const.fallback_radius, Enum.TeamType.TEAM_ENEMY, true, true)
    local closest_creep, creep_score = nil, math.huge
    for i = 1, #creeps do
        local creep = creeps[i]
        if NPC.IsCreep(creep) and is_valid_target(creep) then
            local score = distance2d(my_pos, Entity.GetAbsOrigin(creep))
            if score < creep_score then
                creep_score = score
                closest_creep = creep
            end
        end
    end
    return closest_creep
end

local function find_lane_anchor(hero)
    if not ui.follow_lane_creeps:Get() then
        return nil
    end
    local allies = Entity.GetUnitsInRadius(hero, 1800, Enum.TeamType.TEAM_FRIEND, true, true)
    local anchor, best_distance = nil, math.huge
    local my_pos = Entity.GetAbsOrigin(hero)

    for i = 1, #allies do
        local unit = allies[i]
        if unit ~= hero and NPC.IsLaneCreep(unit) and Entity.IsAlive(unit) then
            local pos = Entity.GetAbsOrigin(unit)
            local d = distance2d(my_pos, pos)
            if d < best_distance then
                anchor = pos
                best_distance = d
            end
        end
    end
    return anchor
end

local function get_fountain_position()
    if state.team and const.base_positions[state.team] then
        return const.base_positions[state.team]
    end
    return Vector()
end

local function order_move(hero, player, position, options)
    if not position then return end
    local now = GameRules.GetGameTime()
    local hero_pos = Entity.GetAbsOrigin(hero)
    local distance = distance2d(hero_pos, position)

    if state.current_move_position then
        local same_destination = distance2d(state.current_move_position, position) < 50
        if same_destination then
            local order_recent = now - (state.current_move_time or 0) < 0.6
            local still_close = distance < 120
            local displaced = state.current_move_distance and (distance - state.current_move_distance) > 120
            if order_recent and still_close and not displaced then
                return
            end
        end
    end

    if not can_issue_move() then
        return
    end

    local is_direct = options and options.direct_move
    local order_type = is_direct and Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION or Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE

    Player.PrepareUnitOrders(
        player,
        order_type,
        nil,
        position,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        hero,
        false,
        false,
        false,
        true,
        "openhyperai_move"
    )
    state.current_move_position = position
    state.current_move_time = now
    state.current_move_distance = distance
    mark_move(ui.move_interval:Get() / 1000.0)
end

local function order_attack(hero, player, target)
    if not target or not is_valid_target(target) then return end
    if state.current_target == target and NPC.IsAttacking(hero) then
        return
    end
    if not can_issue_attack() then
        return
    end
    Player.AttackTarget(player, hero, target, false, false, true, "openhyperai_attack", true)
    state.current_target = target
    state.current_move_position = nil
    state.current_move_time = 0
    state.current_move_distance = nil
    mark_attack(0.05)
end

local function cast_offensive_items(hero, target)
    if not ui.use_items:Get() or not target then return false end

    local used = false
    for slot = 0, 16 do
        local item = NPC.GetItemByIndex(hero, slot)
        if item and can_cast_ability(hero, item, target, { is_item = true }) then
            local behavior = Ability.GetBehavior(item)
            local cast_range = Ability.GetCastRange(item) or 0
            local bonus = NPC.GetCastRangeBonus(hero)
            local pos = Entity.GetAbsOrigin(target)
            local my_pos = Entity.GetAbsOrigin(hero)
            local in_range = cast_range <= 0 or distance2d(my_pos, pos) <= cast_range + bonus + 75

            if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) and in_range then
                Ability.CastTarget(item, target, false, false, true, "openhyperai_item")
                used = true
            elseif has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) and in_range then
                Ability.CastPosition(item, pos, false, false, true, "openhyperai_item", true)
                used = true
            elseif has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) and in_range then
                Ability.CastNoTarget(item, false, false, true, "openhyperai_item")
                used = true
            end

            if used then
                mark_ability_used(item, const.ability_buffer)
                break
            end
        end
    end
    return used
end

local function cast_combat_ability(hero, ability, target)
    if not ability then
        return false
    end
    if not can_cast_ability(hero, ability, target) then
        return false
    end

    if cast_with_behavior(hero, ability, target, nil) then
        mark_ability_used(ability, ui.combo_window:Get())
        return true
    end

    return false
end

local function cast_combat_abilities(hero, target)
    if not ui.use_spells:Get() then
        return false
    end
    local used = false
    for slot = 0, 25 do
        local ability = NPC.GetAbilityByIndex(hero, slot)
        if cast_combat_ability(hero, ability, target) then
            used = true
            break
        end
    end
    return used
end

local function should_retreat(hero, threat_info)
    if not ui.retreat:Get() then
        return false
    end
    if threat_info.level == "high" then
        return true
    end
    local hp = Entity.GetHealth(hero)
    local max_hp = Entity.GetMaxHealth(hero)
    if max_hp == 0 then
        return false
    end
    local pct = (hp / max_hp) * 100
    return pct <= ui.retreat_threshold:Get()
end

local function is_position_safe(hero, position)
    local enemies = Entity.GetHeroesInRadius(hero, 1600, Enum.TeamType.TEAM_ENEMY, true, true)
    for i = 1, #enemies do
        local enemy = enemies[i]
        if is_valid_target(enemy) then
            local dist = distance2d(position, Entity.GetAbsOrigin(enemy))
            if dist <= 900 then
                return false
            end
        end
    end
    return true
end

local function find_neutral_target(hero)
    if not ui.farm_neutrals:Get() then
        return nil
    end
    local neutrals = Entity.GetUnitsInRadius(hero, const.neutral_scan_radius, Enum.TeamType.TEAM_NEUTRAL, true, true)
    local my_pos = Entity.GetAbsOrigin(hero)
    local best_unit, best_score = nil, math.huge
    for i = 1, #neutrals do
        local unit = neutrals[i]
        if NPC.IsCreep(unit) and Entity.IsAlive(unit) then
            local score = distance2d(my_pos, Entity.GetAbsOrigin(unit))
            if score < best_score then
                best_score = score
                best_unit = unit
            end
        end
    end
    return best_unit
end

local function find_enemy_structure(hero)
    if not ui.push_structures:Get() then
        return nil
    end
    local structures = Entity.GetUnitsInRadius(hero, const.structure_scan_radius, Enum.TeamType.TEAM_ENEMY, true, true)
    local my_pos = Entity.GetAbsOrigin(hero)
    local best, best_score = nil, math.huge
    for i = 1, #structures do
        local building = structures[i]
        if NPC.IsTower(building) or NPC.IsBarracks(building) or NPC.IsFort(building) then
            local score = distance2d(my_pos, Entity.GetAbsOrigin(building))
            if score < best_score then
                best = building
                best_score = score
            end
        end
    end
    return best
end

local function find_nearest_rune(hero)
    if not ui.rune_hunt:Get() then
        return nil
    end

    local runes = {
        Entities.GetAllByClassname("dota_item_rune_spawner_powerup"),
        Entities.GetAllByClassname("dota_item_rune_spawner_bounty"),
    }
    local my_pos = Entity.GetAbsOrigin(hero)
    local closest, best_dist = nil, math.huge
    for i = 1, #runes do
        local list = runes[i]
        if list then
            for _, rune in pairs(list) do
                local pos = Entity.GetAbsOrigin(rune)
                local d = distance2d(my_pos, pos)
                if d < best_dist and d <= const.rune_scan_radius then
                    closest = pos
                    best_dist = d
                end
            end
        end
    end
    return closest
end

local function control_allied_units(hero, player, target)
    if not ui.control_allies:Get() then
        return
    end
    if not can_issue_unit_command() then
        return
    end

    local player_id = Players.GetPlayerID(player)
    local hero_pos = Entity.GetAbsOrigin(hero)
    local units = Entity.GetUnitsInRadius(hero, 2500, Enum.TeamType.TEAM_FRIEND, true, true)

    for i = 1, #units do
        local unit = units[i]
        if unit ~= hero and NPC.IsControllableByPlayer(unit, player_id) and Entity.IsAlive(unit) then
            if target and is_valid_target(target) then
                Player.AttackTarget(player, unit, target, false, false, true, "openhyperai_unit", true)
            elseif ui.illusion_split:Get() and NPC.IsIllusion(unit) then
                local lane_anchor = find_lane_anchor(unit)
                if lane_anchor then
                    Player.PrepareUnitOrders(
                        player,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                        nil,
                        lane_anchor,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        unit,
                        false,
                        false,
                        false,
                        true,
                        "openhyperai_unit_split"
                    )
                else
                    local offset = hero_pos + Vector(math.random(-400, 400), math.random(-400, 400), 0)
                    Player.PrepareUnitOrders(
                        player,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                        nil,
                        offset,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        unit,
                        false,
                        false,
                        false,
                        true,
                        "openhyperai_unit_split"
                    )
                end
            elseif state.idle_position then
                Player.PrepareUnitOrders(
                    player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                    nil,
                    state.idle_position,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    unit,
                    false,
                    false,
                    false,
                    true,
                    "openhyperai_unit_idle"
                )
            end
        end
    end

    mark_unit_command(ui.unit_update_interval:Get() / 1000.0)
end

local function kite_melee_enemies(hero, player, threat_info)
    if not ui.kite_melee:Get() then
        return false
    end
    if threat_info.level == "high" then
        return false
    end

    local melee_units = Entity.GetUnitsInRadius(hero, 250, Enum.TeamType.TEAM_ENEMY, true, true)
    if #melee_units == 0 then
        return false
    end

    local hero_pos = Entity.GetAbsOrigin(hero)
    local retreat_dir = Vector()
    for i = 1, #melee_units do
        local unit = melee_units[i]
        if is_valid_target(unit) then
            retreat_dir = retreat_dir + (hero_pos - Entity.GetAbsOrigin(unit)):Normalized()
        end
    end
    if retreat_dir:Length2D() == 0 then
        return false
    end
    retreat_dir = retreat_dir:Normalized()
    local new_position = hero_pos + retreat_dir * const.kiting_distance
    order_move(hero, state.player, new_position, { direct_move = true })
    return true
end
--#endregion

--#region macro behaviours
local function handle_retreat(hero, player, threat_info)
    state.idle_position = nil
    if cast_defensive_items(hero, threat_info) then
        debug("Used defensive item while retreating")
    end
    cast_mobility_items(hero, state.current_target, threat_info)
    local fountain = get_fountain_position()
    order_move(hero, player, fountain, { direct_move = true })
end

local function handle_idle_actions(hero, player)
    local neutral = find_neutral_target(hero)
    if neutral then
        local pos = Entity.GetAbsOrigin(neutral)
        state.idle_position = pos
        order_move(hero, player, pos)
        return
    end

    local structure = find_enemy_structure(hero)
    if structure and is_valid_target(structure) then
        state.idle_position = Entity.GetAbsOrigin(structure)
        order_move(hero, player, state.idle_position)
        return
    end

    local rune_pos = find_nearest_rune(hero)
    if rune_pos and is_position_safe(hero, rune_pos) then
        state.idle_position = rune_pos
        order_move(hero, player, rune_pos, { direct_move = true })
        return
    end

    if ui.follow_lane_creeps:Get() then
        order_move(hero, player, get_fountain_position())
    else
        if not state.idle_position then
            state.idle_position = Entity.GetAbsOrigin(hero)
        end
        local hero_pos = Entity.GetAbsOrigin(hero)
        local idle_distance = distance2d(hero_pos, state.idle_position)
        if idle_distance > 175 then
            order_move(hero, player, state.idle_position)
        else
            Player.HoldPosition(player, hero, false, "openhyperai_hold")
        end
    end
end

local function handle_combat(hero, player, threat_info)
    if state.current_target and not is_valid_target(state.current_target) then
        state.current_target = nil
    end

    local target = select_enemy(hero)
    if target then
        state.current_target = target
        control_allied_units(hero, player, target)
        if cast_defensive_items(hero, threat_info) then
            debug("Used defensive item during combat")
        end
        if cast_healing_items(hero, threat_info) then
            debug("Consumed healing")
        end
        if cast_mobility_items(hero, target, threat_info) then
            debug("Mobility item used")
        end
        if kite_melee_enemies(hero, player, threat_info) then
            return
        end
        if cast_combat_abilities(hero, target) then
            return
        end
        if cast_offensive_items(hero, target) then
            return
        end
        order_attack(hero, player, target)
    else
        state.current_target = nil
        local lane_anchor = find_lane_anchor(hero)
        if lane_anchor then
            state.idle_position = lane_anchor
            order_move(hero, player, lane_anchor)
        else
            handle_idle_actions(hero, player)
        end
        control_allied_units(hero, player, nil)
    end
end
--#endregion

--#region callbacks
function autoplay.OnUpdate()
    if not ui.enabled:Get() then
        return
    end

    if not refresh_handles() then
        return
    end

    local hero = state.hero
    if not Entity.IsAlive(hero) or NPC.IsChannellingAbility(hero) then
        return
    end

    local player = state.player
    state.last_update = GameRules.GetGameTime()

    local threat_info = evaluate_threat(hero)

    if should_retreat(hero, threat_info) then
        state.current_target = nil
        handle_retreat(hero, player, threat_info)
        return
    end

    cast_healing_items(hero, threat_info)
    handle_combat(hero, player, threat_info)
end

function autoplay.OnGameStart()
    reset_state()
end

autoplay.OnGameClose = reset_state
autoplay.OnGameEnd = reset_state

return autoplay

