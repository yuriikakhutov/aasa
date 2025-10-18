---@diagnostic disable: undefined-global

--[[
    Umbrella camera auto-lock helper.
    Keeps the spectator camera locked on the hero that was clicked in the top bar / unit
    selection. The behaviour mimics the Dota 2 double-click portrait follow feature and can
    optionally be configured to react to single clicks instead. The script runs inside the
    UCZone (Umbrella) scripting runtime.
--]]

local camera_lock = {}

--#region menu
local menu_root = Menu.Create("Utility", "Camera", "Umbrella", "Auto Lock")
local menu_group = menu_root:Create("Settings")

local ui = {
    enabled = menu_group:Switch("Enable camera auto-lock", true),
    require_double_click = menu_group:Switch("Require double click to toggle", true),
    double_click_window = menu_group:Slider("Double click window (ms)", 350, 150, 600, "%.0f"),
    update_interval = menu_group:Slider("Camera update interval (ms)", 35, 10, 200, "%.0f"),
    unlock_bind = menu_group:Bind("Hold to pause camera follow", Enum.ButtonCode.KEY_SPACE),
    reset_bind = menu_group:Bind("Press to stop following", Enum.ButtonCode.KEY_ESCAPE),
    follow_illusions = menu_group:Switch("Allow following illusions", false),
    debug = menu_group:Switch("Print debug messages", false),
}
--#endregion

--#region state
local state = {
    player = nil,
    follow_target = nil,
    last_camera_update = 0,
    last_click_target = nil,
    last_click_time = 0,
}
--#endregion

--#region helpers
local function debug_print(message)
    if not ui.debug:Get() then
        return
    end

    Log.Write(string.format("[UmbrellaCam] %s", message))
end

local function reset_follow(reason)
    if state.follow_target and reason then
        debug_print(reason)
    end

    state.follow_target = nil
    state.last_camera_update = 0
end

local function refresh_player_handle()
    if state.player and Players.Contains(state.player) then
        return state.player
    end

    state.player = Players.GetLocal()
    return state.player
end

local function is_valid_follow_target(unit)
    if not unit or Entity.IsDormant(unit) or not Entity.IsAlive(unit) then
        return false
    end

    if not Entity.IsHero(unit) then
        return false
    end

    if not ui.follow_illusions:Get() and NPC.IsIllusion(unit) then
        return false
    end

    return true
end

local function get_selected_hero(player)
    local selected_units = Player.GetSelectedUnits(player)
    if not selected_units or #selected_units == 0 then
        return nil
    end

    for _, unit in ipairs(selected_units) do
        if is_valid_follow_target(unit) then
            return unit
        end
    end

    return nil
end

local function update_camera(game_time)
    if not state.follow_target then
        return
    end

    if not is_valid_follow_target(state.follow_target) then
        reset_follow("Follow target lost")
        return
    end

    local interval = math.max(0.01, ui.update_interval:Get() / 1000.0)
    if game_time - state.last_camera_update < interval then
        return
    end

    state.last_camera_update = game_time
    local position = Entity.GetAbsOrigin(state.follow_target)
    Engine.LookAt(position.x, position.y)
end

local function toggle_follow(target)
    if state.follow_target == target then
        reset_follow("Camera unlocked")
        return
    end

    state.follow_target = target
    state.last_camera_update = 0

    if target and ui.debug:Get() then
        local unit_name = NPC.GetUnitName(target)
        debug_print("Camera locked on " .. unit_name)
    end

    -- perform an immediate camera snap
    local position = Entity.GetAbsOrigin(target)
    Engine.LookAt(position.x, position.y)
    state.last_camera_update = GameRules.GetGameTime()
end
--#endregion

--#region callbacks
function camera_lock.OnUpdate()
    if not ui.enabled:Get() then
        return
    end

    if not Engine.IsInGame() then
        reset_follow()
        state.player = nil
        return
    end

    local player = refresh_player_handle()
    if not player then
        reset_follow("No local player")
        return
    end

    if Input.IsInputCaptured() then
        return
    end

    local game_time = GameRules.GetGameTime()

    if ui.reset_bind:IsPressed() then
        reset_follow("Manual unlock")
        state.last_click_target = nil
        state.last_click_time = 0
        return
    end

    local selected_hero = get_selected_hero(player)

    if ui.require_double_click:Get() then
        if selected_hero and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then
            local elapsed = game_time - state.last_click_time
            local window = ui.double_click_window:Get() / 1000.0

            if state.last_click_target == selected_hero and elapsed <= window then
                toggle_follow(selected_hero)
                state.last_click_target = nil
                state.last_click_time = 0
            else
                state.last_click_target = selected_hero
                state.last_click_time = game_time
            end
        elseif not selected_hero then
            state.last_click_target = nil
        end
    else
        if selected_hero and selected_hero ~= state.follow_target then
            toggle_follow(selected_hero)
        end
    end

    if state.follow_target then
        if ui.unlock_bind:IsDown() then
            debug_print("Camera follow paused (hold)")
            return
        end

        update_camera(game_time)
    end
end
--#endregion

return camera_lock
