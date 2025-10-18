---@diagnostic disable: undefined-global

--[[
    Umbrella helper that converts right mouse button presses into attack-move
    orders near the local hero.  Whenever the player issues a right click the
    script finds the controlled hero and queues a short-range force attack so
    the unit keeps fighting around its current position.
--]]

local force_attack = {}

local function detect_right_button()
    if not Enum or not Enum.ButtonCode then
        return nil
    end

    local candidates = {
        "BUTTON_CODE_MOUSE_RIGHT",
        "MOUSE_RIGHT",
        "BUTTON_CODE_MOUSE_2",
        "MOUSE2",
        "KEY_RBUTTON",
    }

    for _, name in ipairs(candidates) do
        local value = Enum.ButtonCode[name]
        if value then
            return value
        end
    end

    return nil
end

local RIGHT_MOUSE_BUTTON = detect_right_button()
local ATTACK_RADIUS = 150.0

local state = {
    player = nil,
    hero = nil,
    right_down = false,
}

local function safe_call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, result = pcall(fn, ...)
    if not ok then
        return nil
    end

    return result
end

local function reset_state()
    state.player = nil
    state.hero = nil
    state.right_down = false
end

local function refresh_handles()
    local player = state.player
    if not player or not safe_call(Players and Players.Contains, player) then
        player = safe_call(Players and Players.GetLocal)
        state.player = player
    end

    local hero = state.hero
    if not hero or not Entity.IsAlive(hero) then
        hero = safe_call(Heroes and Heroes.GetLocal)
        state.hero = hero
    end

    return state.player ~= nil and state.hero ~= nil
end

local function random_offset(radius)
    local angle = math.random() * math.pi * 2
    local distance = math.random() * radius
    return Vector(math.cos(angle) * distance, math.sin(angle) * distance, 0)
end

local function issue_attack_move()
    if not state.hero or not state.player then
        return
    end

    local hero_pos = Entity.GetAbsOrigin(state.hero)
    if not hero_pos then
        return
    end

    local offset = random_offset(ATTACK_RADIUS)
    local target_pos = hero_pos
    local ok, sum = pcall(function()
        return hero_pos + offset
    end)
    if ok and sum then
        target_pos = sum
    end

    if safe_call(Player and Player.PrepareUnitOrders, state.player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
        nil,
        target_pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        state.hero,
        false,
        false,
        false,
        true,
        "force_attack_rmb"
    ) then
        return
    end

    safe_call(Player and Player.AttackMove, state.player, state.hero, target_pos, false, false, true, "force_attack_rmb")
end

local function is_right_click()
    if not RIGHT_MOUSE_BUTTON then
        return false
    end

    local pressed = safe_call(Input and Input.IsKeyDownOnce, RIGHT_MOUSE_BUTTON)
    if pressed ~= nil then
        return pressed
    end

    pressed = safe_call(Input and Input.IsKeyDown, RIGHT_MOUSE_BUTTON)
    if pressed ~= nil then
        if pressed then
            if not state.right_down then
                state.right_down = true
                return true
            end
        else
            state.right_down = false
        end
        return false
    end

    pressed = safe_call(Input and Input.IsButtonDownOnce, RIGHT_MOUSE_BUTTON)
    if pressed ~= nil then
        return pressed
    end

    pressed = safe_call(Input and Input.IsButtonDown, RIGHT_MOUSE_BUTTON)
    if pressed ~= nil then
        if pressed then
            if not state.right_down then
                state.right_down = true
                return true
            end
        else
            state.right_down = false
        end
    end

    return false
end

function force_attack.OnUpdate()
    if not Engine.IsInGame() then
        reset_state()
        return
    end

    if safe_call(Input and Input.IsInputCaptured) then
        return
    end

    if not refresh_handles() then
        return
    end

    if not Entity.IsAlive(state.hero) then
        return
    end

    if is_right_click() then
        issue_attack_move()
    end
end

return force_attack
