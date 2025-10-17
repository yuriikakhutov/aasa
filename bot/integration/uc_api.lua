local util = require("core.util")

local M = {
    _player = nil,
}

local bit = bit32 or bit

local function ensure_player()
    if M._player and Entity.IsEntity and Entity.IsEntity(M._player) then
        return M._player
    end
    if Players and Players.GetLocal then
        M._player = Players.GetLocal()
    end
    return M._player
end

function M.self()
    if Heroes and Heroes.GetLocal then
        return Heroes.GetLocal()
    end
    return nil
end

function M.player()
    return ensure_player()
end

function M.team()
    local hero = M.self()
    if hero then
        return Entity.GetTeamNum(hero)
    end
    return nil
end

function M.time()
    if GameRules and GameRules.GetGameTime then
        return GameRules.GetGameTime()
    end
    return 0
end

function M.is_valid(entity)
    return entity ~= nil and Entity.IsEntity(entity)
end

function M.move_to(position)
    local hero = M.self()
    if not hero or not position then
        return
    end
    NPC.MoveTo(hero, position, false, false, false, true)
end

function M.attack(target)
    local hero = M.self()
    local player = ensure_player()
    if not hero or not target or not player then
        return
    end
    Player.AttackTarget(player, hero, target, false, false, true, "uczone_attack", true)
end

function M.stop()
    local hero = M.self()
    local player = ensure_player()
    if not hero or not player then
        return
    end
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
        nil,
        Entity.GetAbsOrigin(hero),
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        hero,
        false,
        false,
        false,
        true,
        "uczone_stop"
    )
end

local function ability_behavior(ability)
    if Ability.GetBehavior then
        return Ability.GetBehavior(ability)
    end
    return 0
end

local function has_behavior(behavior, flag)
    if not behavior or not flag then
        return false
    end
    if bit then
        return bit.band(behavior, flag) ~= 0
    end
    return false
end

function M.cast(ability, target)
    if not ability then
        return false
    end
    if not Ability.IsReady(ability) then
        return false
    end
    local behavior = ability_behavior(ability)
    if target and type(target) == "userdata" and Entity.IsEntity(target) then
        if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
            Ability.CastTarget(ability, target, false, false, true, "uczone_cast")
            return true
        end
    elseif target and type(target) == "userdata" then
        if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT)
            or has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING) then
            Ability.CastPosition(ability, target, false, false, true, "uczone_cast", true)
            return true
        end
    end
    if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
        Ability.CastNoTarget(ability, false, false, true, "uczone_cast")
        return true
    end
    return false
end

function M.toggle(ability)
    if not ability then
        return false
    end
    if has_behavior(ability_behavior(ability), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_TOGGLE) then
        Ability.Toggle(ability, false, false, true, "uczone_toggle")
        return true
    end
    return false
end

function M.find_ability(hero, name)
    if not hero or not name then
        return nil
    end
    for i = 0, 23 do
        local ability = NPC.GetAbilityByIndex(hero, i)
        if ability and Ability.GetName(ability) == name then
            return ability
        end
    end
    return nil
end

function M.iterate_abilities(hero)
    local abilities = {}
    if not hero then
        return abilities
    end
    for i = 0, 23 do
        local ability = NPC.GetAbilityByIndex(hero, i)
        if ability then
            local name = Ability.GetName(ability)
            abilities[name] = {
                handle = ability,
                level = Ability.GetLevel and Ability.GetLevel(ability) or 0,
                cooldown = Ability.GetCooldown(ability),
                manaCost = Ability.GetManaCost(ability),
                behavior = ability_behavior(ability),
                damage = Ability.GetDamage and Ability.GetDamage(ability) or 0,
                lastUsed = Ability.SecondsSinceLastUse and Ability.SecondsSinceLastUse(ability) or math.huge,
            }
        end
    end
    return abilities
end

function M.iterate_items(hero)
    local items = {}
    if not hero then
        return items
    end
    for slot = 0, 8 do
        local item = NPC.GetItemByIndex(hero, slot)
        if item then
            local name = Ability.GetName(item)
            items[name] = {
                handle = item,
                cooldown = Ability.GetCooldown(item),
                manaCost = Ability.GetManaCost(item),
                behavior = ability_behavior(item),
            }
        end
    end
    local neutral = NPC.GetNeutralItem and NPC.GetNeutralItem(hero) or nil
    if neutral then
        local name = Ability.GetName(neutral)
        items[name] = {
            handle = neutral,
            cooldown = Ability.GetCooldown(neutral),
            manaCost = Ability.GetManaCost(neutral),
            behavior = ability_behavior(neutral),
        }
    end
    return items
end

function M.ping(position, message)
    if Minimap and Minimap.Ping then
        Minimap.Ping(position, message or "BOT")
    end
end

return M
