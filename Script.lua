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
    next_bind_refresh = nil,
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
    state.next_bind_refresh = nil
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

local KEYBIND_FILES = {
    "cfg/keyboard_personal.vcfg",
    "cfg/keyboard.vcfg",
    "cfg/config.cfg",
    "game/dota/cfg/keyboard_personal.vcfg",
    "game/dota/cfg/keyboard.vcfg",
    "game/dota/cfg/config.cfg",
    "../cfg/keyboard_personal.vcfg",
    "../cfg/keyboard.vcfg",
    "../cfg/config.cfg",
    "keyboard_personal.vcfg",
    "keyboard.vcfg",
    "config.cfg",
}

local SPECIAL_KEY_ALIASES = {
    ["["] = "KEY_LBRACKET",
    ["]"] = "KEY_RBRACKET",
    [";"] = "KEY_SEMICOLON",
    ["'"] = "KEY_APOSTROPHE",
    ["`"] = "KEY_BACKQUOTE",
    [","] = "KEY_COMMA",
    ["."] = "KEY_PERIOD",
    ["/"] = "KEY_SLASH",
    ["\\"] = "KEY_BACKSLASH",
    ["-"] = "KEY_MINUS",
    ["="] = "KEY_EQUAL",
}

local KEY_NAME_ALIASES = {
    MOUSE1 = "KEY_MOUSE1",
    MOUSE2 = "KEY_MOUSE2",
    MOUSE3 = "KEY_MOUSE3",
    MOUSE4 = "KEY_MOUSE4",
    MOUSE5 = "KEY_MOUSE5",
    MOUSE_LEFT = "KEY_MOUSE1",
    MOUSE_RIGHT = "KEY_MOUSE2",
    MOUSE_MIDDLE = "KEY_MOUSE3",
    MWHEELUP = "KEY_MWHEELUP",
    MWHEELDOWN = "KEY_MWHEELDOWN",
    WHEELUP = "KEY_MWHEELUP",
    WHEELDOWN = "KEY_MWHEELDOWN",
    MOUSEWHEELUP = "KEY_MWHEELUP",
    MOUSEWHEELDOWN = "KEY_MWHEELDOWN",
    SPACEBAR = "KEY_SPACE",
}

local ATTACK_COMMANDS = {
    ["mc_attack"] = true,
    ["mc_attackmove"] = true,
    ["attack"] = true,
    ["attackmove"] = true,
    ["attack_move"] = true,
    ["+attack"] = true,
    ["+attack2"] = true,
    ["+attackmove"] = true,
    ["dota_attack"] = true,
    ["dota_force_attack"] = true,
    ["force_attack"] = true,
    ["+force_attack"] = true,
}

local function read_file(path)
    local ok, data = pcall(function()
        local file = io.open(path, "r")
        if not file then
            return nil
        end

        local content = file:read("*a")
        file:close()
        return content
    end)

    if not ok then
        return nil
    end

    return data
end

local function resolve_button_code_from_name(name)
    if not Enum or not Enum.ButtonCode then
        return nil
    end

    if type(name) ~= "string" then
        return nil
    end

    local trimmed = name:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil
    end

    local alias = SPECIAL_KEY_ALIASES[trimmed]
    if alias then
        return detect_button({ alias })
    end

    local normalized = trimmed:upper()

    alias = SPECIAL_KEY_ALIASES[normalized]
    if alias then
        local code = detect_button({ alias })
        if code then
            return code
        end
    end

    local candidates = {}

    local alias_name = KEY_NAME_ALIASES[normalized]
    if alias_name then
        table.insert(candidates, alias_name)
    end

    table.insert(candidates, normalized)

    if not normalized:find("^KEY_") then
        table.insert(candidates, "KEY_" .. normalized)
    end

    if normalized:match("^NUMPAD") then
        table.insert(candidates, "KEY_PAD_" .. normalized:sub(7))
    end

    if normalized:match("^KP_") then
        table.insert(candidates, "KEY_PAD_" .. normalized:sub(4))
    end

    if normalized:match("^PAD_") then
        table.insert(candidates, "KEY_" .. normalized)
    end

    if #normalized == 1 then
        table.insert(candidates, "KEY_" .. normalized)
    end

    if normalized:match("^MOUSE") then
        table.insert(candidates, "KEY_" .. normalized)
        table.insert(candidates, normalized:gsub("^MOUSE", "MOUSE_"))
    end

    return detect_button(candidates)
end

local function is_attack_command(command)
    if type(command) ~= "string" then
        return false
    end

    local normalized = command:lower():gsub("%s+", "")
    return ATTACK_COMMANDS[normalized] or false
end

local function gather_attack_key_names(text, output)
    if not text then
        return
    end

    for key, command in text:gmatch('bind%s+"([^"]+)"%s+"([^"]+)"') do
        if is_attack_command(command) then
            output[key] = true
        end
    end

    for key, command in text:gmatch('"([^"]+)"%s+"([^"]+)"') do
        if is_attack_command(command) then
            output[key] = true
        end
    end
end

local function collect_attack_key_codes()
    local names = {}

    for _, path in ipairs(KEYBIND_FILES) do
        gather_attack_key_names(read_file(path), names)
    end

    local codes = {}
    local seen = {}

    for key in pairs(names) do
        local code = resolve_button_code_from_name(key)
        if code and not seen[code] then
            table.insert(codes, code)
            seen[code] = true
        end
    end

    table.sort(codes, function(a, b)
        return a < b
    end)

    return codes
end

local function refresh_attack_binding(force)
    local now = safe_call(GameRules and GameRules.GetGameTime)
    if not force and now and state.next_bind_refresh and now < state.next_bind_refresh then
        return
    end

    if now then
        state.next_bind_refresh = now + 2.0
    else
        state.next_bind_refresh = nil
    end

    local use_right = read_force_right_click()
    state.use_right_click = use_right

    local attack_buttons = {}
    local seen = {}

    local function add_button(code)
        if not code or seen[code] then
            return
        end

        table.insert(attack_buttons, code)
        seen[code] = true
    end

    if use_right == true then
        add_button(RIGHT_MOUSE_BUTTON)
    elseif use_right == false then
        add_button(LEFT_MOUSE_BUTTON)
    else
        add_button(RIGHT_MOUSE_BUTTON)
        add_button(LEFT_MOUSE_BUTTON)
    end

    local keyboard_codes = collect_attack_key_codes()
    local added_keyboard = false

    for _, code in ipairs(keyboard_codes) do
        add_button(code)
        added_keyboard = true
    end

    if not added_keyboard then
        add_button(resolve_button_code_from_name("A") or resolve_button_code_from_name("KEY_A"))
    end

    if #attack_buttons == 0 then
        add_button(RIGHT_MOUSE_BUTTON)
        add_button(LEFT_MOUSE_BUTTON)
    end

    state.attack_buttons = attack_buttons
    state.button_down = {}
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
