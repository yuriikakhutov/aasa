---@diagnostic disable: undefined-global

--[[
    Umbrella helper that mirrors the player's force-attack binding.  When the
    attack/force-attack mouse button is clicked the script reads the world
    cursor position and queues an attack-move order for the local hero at that
    spot.  The helper respects the "Right Click to Force Attack" option,
    automatically falling back to the left button if right click is not
    configured and defaulting to the right button if the setting cannot be
    queried.
]]

local force_attack = {}

local function detect_button(names)
    if not Enum or not Enum.ButtonCode then
        return nil
    end

    for _, name in ipairs(names) do
        local value = Enum.ButtonCode[name]
        if value ~= nil then
            return value
        end
    end

    return nil
end

local RIGHT_MOUSE_BUTTON = detect_button({
    "BUTTON_CODE_MOUSE_RIGHT",
    "MOUSE_RIGHT",
    "BUTTON_CODE_MOUSE_2",
    "MOUSE2",
    "KEY_RBUTTON",
})

local LEFT_MOUSE_BUTTON = detect_button({
    "BUTTON_CODE_MOUSE_LEFT",
    "MOUSE_LEFT",
    "BUTTON_CODE_MOUSE_1",
    "MOUSE1",
    "KEY_LBUTTON",
})

local state = {
    player = nil,
    hero = nil,
    button_down = {},
    use_right_click = nil,
    attack_buttons = nil,
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
    state.button_down = {}
    state.use_right_click = nil
    state.attack_buttons = nil
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

local function parse_convar_bool(value)
    if value == nil then
        return nil
    end

    if type(value) == "boolean" then
        return value
    end

    if type(value) == "number" then
        return value ~= 0
    end

    if type(value) == "string" then
        local normalized = value:lower()
        if normalized == "1" or normalized == "true" then
            return true
        end
        if normalized == "0" or normalized == "false" then
            return false
        end
    end

    return nil
end

local function read_force_right_click()
    local value = safe_call(Convars and Convars.GetBool, "dota_force_right_click_attack")
    local parsed = parse_convar_bool(value)
    if parsed ~= nil then
        return parsed
    end

    value = safe_call(Convars and Convars.GetInt, "dota_force_right_click_attack")
    parsed = parse_convar_bool(value)
    if parsed ~= nil then
        return parsed
    end

    value = safe_call(Console and Console.GetConVar, "dota_force_right_click_attack")
    parsed = parse_convar_bool(value)
    if parsed ~= nil then
        return parsed
    end

    return nil
end

local function refresh_attack_binding()
    local use_right = read_force_right_click()
    if use_right == nil then
        use_right = true
    end

    if state.use_right_click == use_right and state.attack_buttons ~= nil then
        return
    end

    state.use_right_click = use_right
    state.attack_buttons = {}
    state.button_down = {}

    if use_right and RIGHT_MOUSE_BUTTON then
        table.insert(state.attack_buttons, RIGHT_MOUSE_BUTTON)
    elseif not use_right and LEFT_MOUSE_BUTTON then
        table.insert(state.attack_buttons, LEFT_MOUSE_BUTTON)
    end

    if #state.attack_buttons == 0 then
        if RIGHT_MOUSE_BUTTON then
            table.insert(state.attack_buttons, RIGHT_MOUSE_BUTTON)
        end
        if LEFT_MOUSE_BUTTON then
            table.insert(state.attack_buttons, LEFT_MOUSE_BUTTON)
        end
    end
end

local function get_cursor_position(hero_pos)
    local cursor_pos = safe_call(Input and Input.GetWorldCursorPos)
    if not cursor_pos then
        return hero_pos
    end

    if hero_pos and cursor_pos.z == nil then
        return Vector(cursor_pos.x, cursor_pos.y, hero_pos.z)
    end

    return cursor_pos
end

local function issue_attack_move()
    if not state.hero or not state.player then
        return
    end

    local hero_pos = Entity.GetAbsOrigin(state.hero)
    if not hero_pos then
        return
    end

    local target_pos = get_cursor_position(hero_pos)
    if not target_pos then
        return
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
        "force_attack_bind"
    ) then
        return
    end

    safe_call(Player and Player.AttackMove, state.player, state.hero, target_pos, false, false, true, "force_attack_bind")
end

local function check_button_once(code)
    local pressed = safe_call(Input and Input.IsButtonDownOnce, code)
    if pressed ~= nil then
        return pressed
    end

    pressed = safe_call(Input and Input.IsKeyDownOnce, code)
    if pressed ~= nil then
        return pressed
    end

    pressed = safe_call(Input and Input.IsButtonDown, code)
    if pressed ~= nil then
        if pressed then
            if not state.button_down[code] then
                state.button_down[code] = true
                return true
            end
        else
            state.button_down[code] = false
        end
        return false
    end

    pressed = safe_call(Input and Input.IsKeyDown, code)
    if pressed ~= nil then
        if pressed then
            if not state.button_down[code] then
                state.button_down[code] = true
                return true
            end
        else
            state.button_down[code] = false
        end
    end

    return false
end

local function is_attack_click()
    if not state.attack_buttons then
        return false
    end

    for _, code in ipairs(state.attack_buttons) do
        if check_button_once(code) then
            return true
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

    refresh_attack_binding()

    if not state.attack_buttons or #state.attack_buttons == 0 then
        return
    end

    if not Entity.IsAlive(state.hero) then
        return
    end

    if is_attack_click() then
        issue_attack_move()
    end
end

return force_attack
