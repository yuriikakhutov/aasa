local M = {
    _player = nil,
}

local bit = bit32 or bit

local function safe_call(func, ...)
    if not func then
        return nil
    end
    local ok, result = pcall(func, ...)
    if not ok then
        return nil
    end
    return result
end

local function ensure_player()
    if M._player and Entity.IsEntity and Entity.IsEntity(M._player) then
        return M._player
    end
    local player = safe_call(Players and Players.GetLocal)
    if player then
        M._player = player
    end
    return M._player
end

function M.self()
    return safe_call(Heroes and Heroes.GetLocal)
end

function M.player()
    return ensure_player()
end

function M.team()
    local hero = M.self()
    if hero and Entity.GetTeamNum then
        return Entity.GetTeamNum(hero)
    end
    return nil
end

function M.getTime()
    return safe_call(GameRules and GameRules.GetGameTime) or 0
end

function M.time()
    return M.getTime()
end

function M.isPlayerControlling()
    local player = ensure_player()
    if not player then
        return false
    end
    if Player and Player.IsControlling then
        local result = safe_call(Player.IsControlling, player)
        if result ~= nil then
            return result and result ~= 0
        end
    end
    if Input and Input.IsInputCaptured then
        local captured = safe_call(Input.IsInputCaptured)
        if captured ~= nil then
            return captured and captured ~= 0
        end
    end
    if Input and Input.IsGameInputEnabled then
        local enabled = safe_call(Input.IsGameInputEnabled)
        if enabled == false then
            return true
        end
    end
    if Input and Input.IsButtonDown and Enum and Enum.ButtonCode and Enum.ButtonCode.MOUSE_LEFT then
        local pressed = safe_call(Input.IsButtonDown, Enum.ButtonCode.MOUSE_LEFT)
        if pressed then
            return true
        end
    end
    return false
end

function M.tpReady()
    local hero = M.self()
    if not hero or not NPC.HasItem then
        return false
    end
    local tp = NPC.HasItem(hero, "item_tpscroll")
    if not tp then
        return false
    end
    if Ability.SecondsSinceLastUse then
        return Ability.SecondsSinceLastUse(tp) > 0
    end
    return true
end

function M.useTP(pos)
    if not pos then
        return false
    end
    local hero = M.self()
    if not hero or not NPC.HasItem then
        return false
    end
    local tp = NPC.HasItem(hero, "item_tpscroll")
    if not tp then
        return false
    end
    if Ability.CastPosition then
        Ability.CastPosition(tp, pos, false, false, true, "uc_tp", true)
        return true
    end
    return false
end

function M.canBuy(item)
    local player = ensure_player()
    if not player or not Shop.CanBeUsed then
        return false
    end
    return Shop.CanBeUsed(player, item)
end

function M.buy(item)
    local player = ensure_player()
    if not player or not Shop.PurchaseItem then
        return false
    end
    return Shop.PurchaseItem(player, item, false, true, "uc_buy")
end

function M.stashPull()
    local player = ensure_player()
    if not player or not Shop.PullFromStash then
        return false
    end
    Shop.PullFromStash(player)
    return true
end

function M.courierSend()
    if Courier and Courier.Send then
        Courier.Send()
        return true
    end
    return false
end

function M.glyph()
    if GameRules and GameRules.UseGlyph then
        GameRules.UseGlyph()
        return true
    end
    return false
end

function M.scan(pos)
    if not pos or not GameRules or not GameRules.CastScan then
        return false
    end
    GameRules.CastScan(pos)
    return true
end

local function safe_table(result)
    if type(result) ~= "table" then
        return {}
    end
    return result
end

function M.runes()
    return safe_table(safe_call(World and World.Runes))
end

function M.camps()
    return safe_table(safe_call(World and World.Camps))
end

function M.lanes()
    return safe_table(safe_call(World and World.Lanes))
end

function M.towers()
    return safe_table(safe_call(World and World.Towers))
end

function M.shrines()
    return safe_table(safe_call(World and World.Shrines))
end

function M.ancients()
    return safe_table(safe_call(World and World.Ancients))
end

function M.creeps(team)
    return safe_table(safe_call(World and World.Creeps, team))
end

function M.heroes()
    return safe_table(safe_call(World and World.Heroes))
end

function M.wards(team)
    return safe_table(safe_call(World and World.Wards, team))
end

function M.nearestShop(shopType)
    if not World or not World.NearestShop then
        return nil
    end
    local hero = M.self()
    if not hero then
        return nil
    end
    return World.NearestShop(hero, shopType)
end

function M.currentGold()
    local hero = M.self()
    if hero and NPC.GetGold then
        return NPC.GetGold(hero, true)
    end
    return 0
end

function M.netWorth()
    local hero = M.self()
    if hero and NPC.GetNetWorth then
        return NPC.GetNetWorth(hero)
    end
    return M.currentGold()
end

function M.talentPoints()
    local hero = M.self()
    if hero and NPC.GetTalentPoints then
        return NPC.GetTalentPoints(hero)
    end
    return 0
end

function M.learnSkill(name)
    local hero = M.self()
    if not hero or not hero or not NPC.GetAbilityByName then
        return false
    end
    local ability = NPC.GetAbilityByName(hero, name)
    if ability and Ability.LevelUp then
        Ability.LevelUp(ability, false, true, "uc_learn")
        return true
    end
    return false
end

function M.availableSkills()
    local hero = M.self()
    if not hero or not NPC.GetAbilityPoints then
        return {}
    end
    if NPC.GetAbilityPoints(hero) <= 0 then
        return {}
    end
    local skills = {}
    for i = 0, 23 do
        local ability = NPC.GetAbilityByIndex(hero, i)
        if ability and Ability.CanLearn and Ability.CanLearn(ability) then
            table.insert(skills, Ability.GetName(ability))
        end
    end
    return skills
end

function M.moveTo(pos)
    local hero = M.self()
    if not hero or not pos or not NPC.MoveTo then
        return false
    end
    NPC.MoveTo(hero, pos, false, false, false, true)
    return true
end

function M.attack(entity)
    local hero = M.self()
    local player = ensure_player()
    if not hero or not entity or not player or not Player.AttackTarget then
        return false
    end
    Player.AttackTarget(player, hero, entity, false, false, true, "uc_attack", true)
    return true
end

function M.hold()
    local hero = M.self()
    local player = ensure_player()
    if not hero or not player or not Player.HoldPosition then
        return false
    end
    Player.HoldPosition(player, hero, false, false, true, "uc_hold")
    return true
end

function M.stop()
    local hero = M.self()
    local player = ensure_player()
    if not hero or not player or not Player.PrepareUnitOrders then
        return false
    end
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
        nil,
        hero and Entity.GetAbsOrigin and Entity.GetAbsOrigin(hero) or Vector(0, 0, 0),
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        hero,
        false,
        false,
        false,
        true,
        "uc_stop"
    )
    return true
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

local function ensure_ability(name)
    local hero = M.self()
    if not hero or not name or not NPC.GetAbilityByName then
        return nil
    end
    return NPC.GetAbilityByName(hero, name)
end

function M.cast(spellId, target)
    local ability = spellId
    if type(spellId) == "string" then
        ability = ensure_ability(spellId)
    end
    if not ability or not Ability.IsReady or not Ability.IsReady(ability) then
        return false
    end
    local behavior = ability_behavior(ability)
    if target and Entity.IsEntity and Entity.IsEntity(target) and has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
        Ability.CastTarget(ability, target, false, false, true, "uc_cast")
        return true
    end
    if target and type(target) == "userdata" and has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) then
        Ability.CastPosition(ability, target, false, false, true, "uc_cast", true)
        return true
    end
    if has_behavior(behavior, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
        Ability.CastNoTarget(ability, false, false, true, "uc_cast")
        return true
    end
    return false
end

function M.useItem(name, target)
    return M.cast(name, target)
end

function M.distance(a, b)
    if not a or not b or not Entity.GetAbsOrigin then
        return math.huge
    end
    local va = Entity.GetAbsOrigin(a)
    local vb = Entity.GetAbsOrigin(b)
    if va and vb and va.Distance2D then
        return va:Distance2D(vb)
    end
    if va and vb then
        local dx = (va.x or 0) - (vb.x or 0)
        local dy = (va.y or 0) - (vb.y or 0)
        return math.sqrt(dx * dx + dy * dy)
    end
    return math.huge
end

function M.isVisible(entity)
    if not entity or not Entity.IsVisible then
        return false
    end
    return Entity.IsVisible(entity)
end

function M.isAlive(entity)
    if not entity or not Entity.IsAlive then
        return false
    end
    return Entity.IsAlive(entity)
end

function M.projectDamage(unit, window)
    if not unit then
        return 0
    end
    if NPC.EstimateIncomingDamage then
        return NPC.EstimateIncomingDamage(unit, window or 2)
    end
    if Entity.GetHealth then
        return Entity.GetMaxHealth(unit) * 0.2
    end
    return 0
end

function M.timeSinceDamaged(unit)
    if not unit or not NPC.GetTimeSinceDamaged then
        return math.huge
    end
    return NPC.GetTimeSinceDamaged(unit)
end

function M.isGankLikely(pos)
    if not pos then
        return false
    end
    if World and World.IsGankLikely then
        return World.IsGankLikely(pos)
    end
    local enemies = M.heroes()
    local hero = M.self()
    if not hero then
        return false
    end
    local count = 0
    for _, enemy in ipairs(enemies) do
        if enemy and enemy.team and hero and Entity.GetTeamNum and enemy.team ~= Entity.GetTeamNum(hero) then
            count = count + 1
        end
    end
    return count >= 2
end

return M
