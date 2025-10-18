---@diagnostic disable: undefined-global, param-type-mismatch

--[[
    Hero camera follow helper for the Umbrella platform.
    The script mirrors Dota 2's native double-click camera centering but keeps
    the camera locked on the clicked hero until the user explicitly releases
    it.  It supports both allied and enemy heroes, optional double-click
    requirement and several safety fallbacks to keep compatibility with
    Umbrella/UCZone builds that expose slightly different helper APIs.
--]]

local camera_lock = {}

--#region menu
local root_tab = Menu.Create("Utility", "Camera", "Hero Lock", "Follow on click")
local general_group = root_tab:Create("General")
local behaviour_group = root_tab:Create("Behaviour")
local release_group = root_tab:Create("Release")

local ui = {
    enabled = general_group:Switch("Enable hero camera lock", true),
    allies_only = behaviour_group:Switch("Lock only on allied heroes", false),
    require_double_click = behaviour_group:Switch("Require double click", true),
    double_click_window = behaviour_group:Slider("Double click window (ms)", 350, 150, 600, "%.0f"),
    search_radius = behaviour_group:Slider("Cursor hero search radius", 220, 100, 600, "%.0f"),
    camera_update = behaviour_group:Slider("Camera update interval (ms)", 33, 16, 160, "%.0f"),

    release_on_escape = release_group:Switch("Release when pressing Escape", true),
    release_on_dead = release_group:Switch("Release when hero dies", true),
    toggle_same_target = release_group:Switch("Double click same hero again to unlock", true),
    notify_changes = release_group:Switch("Show notifications", true),
}
local BUTTON_LEFT = Enum and Enum.ButtonCode and Enum.ButtonCode.MOUSE_LEFT
local KEY_ESCAPE = Enum and Enum.ButtonCode and Enum.ButtonCode.KEY_ESCAPE
--#endregion

--#region state
local state = {
    player = nil,
    hero = nil,
    team = nil,
    last_click_time = 0,
    last_click_target = nil,
    locked_target = nil,
    lock_acquired_at = 0,
    next_camera_update = 0,
    pressed_cache = {},
}
--#endregion

--#region helpers
local function notify(message)
    if not ui.notify_changes:Get() then
        return
    end
    Notifications.AddBottom(message, 2.5)
end

local function reset_state()
    state.player = nil
    state.hero = nil
    state.team = nil
    state.last_click_time = 0
    state.last_click_target = nil
    state.locked_target = nil
    state.lock_acquired_at = 0
    state.next_camera_update = 0
    state.pressed_cache = {}
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
    return state.player ~= nil
end

local function is_valid_hero(entity)
    if not entity or not NPC.IsHero(entity) then
        return false
    end
    if Entity.IsDormant(entity) then
        return false
    end
    if ui.allies_only:Get() and state.team and Entity.GetTeamNum(entity) ~= state.team then
        return false
    end
    return true
end

local function is_button_pressed(code)
    if not Input or not code then
        return false
    end

    if Input.IsButtonPressed then
        local ok, pressed = pcall(Input.IsButtonPressed, code)
        if ok then
            return pressed
        end
    end
    if Input.IsKeyPressed then
        local ok, pressed = pcall(Input.IsKeyPressed, code)
        if ok then
            return pressed
        end
    end
    if Input.IsKeyDown then
        local ok, down = pcall(Input.IsKeyDown, code)
        if ok then
            local was_down = state.pressed_cache[code]
            state.pressed_cache[code] = down
            return down and not was_down
        end
    end
    return false
end

local function vector_components(vec)
    if not vec then
        return 0, 0, 0
    end
    if vec.GetX and vec.GetY and vec.GetZ then
        local ok_x, x = pcall(vec.GetX, vec)
        local ok_y, y = pcall(vec.GetY, vec)
        local ok_z, z = pcall(vec.GetZ, vec)
        if ok_x and ok_y and ok_z then
            return x, y, z
        end
    end
    return vec.x or 0, vec.y or 0, vec.z or 0
end

local function try_execute_console(command)
    if Engine and Engine.ExecuteCommand then
        local ok = pcall(Engine.ExecuteCommand, command)
        if ok then return true end
    end
    if Console and Console.ExecuteCommand then
        local ok = pcall(Console.ExecuteCommand, command)
        if ok then return true end
    end
    if GameConsole and GameConsole.ExecuteCommand then
        local ok = pcall(GameConsole.ExecuteCommand, command)
        if ok then return true end
    end
    return false
end

local function try_set_camera_target(target)
    if not target or not state.player then
        return false
    end
    if Player and Player.SetCameraTarget then
        local ok = pcall(Player.SetCameraTarget, state.player, target)
        if ok then
            return true
        end
    end
    if Players and Players.SetCameraTarget then
        local ok = pcall(Players.SetCameraTarget, state.player, target)
        if ok then
            return true
        end
    end
    return false
end

local function release_camera()
    if not state.locked_target then
        return
    end
    if not try_set_camera_target(nil) then
        try_execute_console("dota_camera_lock 0")
    end
    state.locked_target = nil
    state.lock_acquired_at = 0
    state.next_camera_update = 0
end

local function gather_heroes()
    local result = {}
    local seen = {}

    local function push(hero)
        if not is_valid_hero(hero) then
            return
        end
        if seen[hero] then
            return
        end
        seen[hero] = true
        result[#result + 1] = hero
    end

    if state.hero then
        push(state.hero)

        local enemy_ok, enemies = pcall(Entity.GetHeroesInRadius, state.hero, 99999, Enum.TeamType.TEAM_ENEMY, true, true)
        if enemy_ok and type(enemies) == "table" then
            for i = 1, #enemies do
                push(enemies[i])
            end
        end

        if not ui.allies_only:Get() then
            local ally_ok, allies = pcall(Entity.GetHeroesInRadius, state.hero, 99999, Enum.TeamType.TEAM_FRIEND, true, true)
            if ally_ok and type(allies) == "table" then
                for i = 1, #allies do
                    push(allies[i])
                end
            end
        end
    end

    if Heroes and Heroes.GetAll then
        local ok, heroes = pcall(Heroes.GetAll)
        if ok and type(heroes) == "table" then
            for _, hero in ipairs(heroes) do
                push(hero)
            end
        end
    end

    return result
end

local function get_hovered_hero()
    if not Input then
        return nil
    end

    if Player and Player.GetClickTarget then
        local ok, target = pcall(Player.GetClickTarget, state.player)
        if ok and is_valid_hero(target) then
            return target
        end
    end

    if Input.GetHoveredEntity then
        local ok, hovered = pcall(Input.GetHoveredEntity)
        if ok and is_valid_hero(hovered) then
            return hovered
        end
    end

    if Input.GetNearestHeroToCursor then
        local ok, hero = pcall(Input.GetNearestHeroToCursor, Enum.TeamType.TEAM_ENEMY, ui.search_radius:Get())
        if ok and is_valid_hero(hero) then
            return hero
        end
        if not ui.allies_only:Get() then
            ok, hero = pcall(Input.GetNearestHeroToCursor, Enum.TeamType.TEAM_FRIEND, ui.search_radius:Get())
            if ok and is_valid_hero(hero) then
                return hero
            end
        end
    end

    local cursor_pos
    if Input.GetWorldCursorPos then
        local ok, pos = pcall(Input.GetWorldCursorPos)
        if ok then
            cursor_pos = pos
        end
    end
    if not cursor_pos and Input.GetCursor3DPosition then
        local ok, pos = pcall(Input.GetCursor3DPosition)
        if ok then
            cursor_pos = pos
        end
    end

    if not cursor_pos then
        return nil
    end

    local heroes = gather_heroes()
    local best_target, best_dist = nil, math.huge
    for i = 1, #heroes do
        local hero = heroes[i]
        local hero_pos = Entity.GetAbsOrigin(hero)
        if hero_pos then
            local dist = (hero_pos - cursor_pos):Length2D()
            if dist < best_dist and dist <= ui.search_radius:Get() then
                best_target = hero
                best_dist = dist
            end
        end
    end

    return best_target
end

local function lock_on(hero)
    if not hero then
        return
    end
    state.locked_target = hero
    state.lock_acquired_at = GameRules.GetGameTime()
    state.next_camera_update = 0

    if not try_set_camera_target(hero) then
        try_execute_console("dota_camera_lock 0")
    end

    local hero_name = NPC.GetUnitName(hero)
    if hero_name then
        notify("Camera locked on " .. hero_name)
    else
        notify("Camera locked")
    end
end

local function update_camera(now)
    local target = state.locked_target
    if not target then
        return
    end

    if ui.release_on_dead:Get() and not Entity.IsAlive(target) then
        notify("Camera released (target dead)")
        release_camera()
        return
    end

    if try_set_camera_target(target) then
        return
    end

    if now < state.next_camera_update then
        return
    end
    state.next_camera_update = now + (ui.camera_update:Get() / 1000.0)

    local pos = Entity.GetAbsOrigin(target)
    if not pos then
        return
    end
    local x, y, z = vector_components(pos)
    try_execute_console(string.format("dota_camera_set_lookatpos %.1f %.1f %.1f", x, y, z))
end

local function handle_clicks(now)
    local hero = get_hovered_hero()
    if not hero then
        return
    end

    if not BUTTON_LEFT then
        return
    end

    if state.locked_target and state.locked_target == hero and ui.toggle_same_target:Get() then
        if is_button_pressed(BUTTON_LEFT) then
            local elapsed = now - state.last_click_time
            local window = ui.double_click_window:Get() / 1000.0
            if elapsed <= window then
                notify("Camera released")
                release_camera()
                state.last_click_time = 0
                state.last_click_target = nil
            else
                state.last_click_time = now
            end
        end
        return
    end

    local pressed = is_button_pressed(BUTTON_LEFT)
    if not pressed then
        return
    end

    if ui.require_double_click:Get() then
        local elapsed = now - state.last_click_time
        local window = ui.double_click_window:Get() / 1000.0
        if state.last_click_target == hero and elapsed <= window then
            lock_on(hero)
            state.last_click_time = 0
            state.last_click_target = nil
        else
            state.last_click_target = hero
            state.last_click_time = now
        end
    else
        lock_on(hero)
    end
end
--#endregion

--#region callbacks
function camera_lock.OnUpdate()
    if not ui.enabled:Get() then
        return
    end

    if not refresh_handles() then
        return
    end

    local now = GameRules.GetGameTime()

    if ui.release_on_escape:Get() and KEY_ESCAPE and is_button_pressed(KEY_ESCAPE) then
        if state.locked_target then
            notify("Camera released (escape)")
        end
        release_camera()
        state.last_click_time = 0
        state.last_click_target = nil
        return
    end

    if state.locked_target then
        update_camera(now)
    end

    handle_clicks(now)
end

function camera_lock.OnGameStart()
    reset_state()
end

camera_lock.OnGameEnd = reset_state
camera_lock.OnGameClose = reset_state

return camera_lock
