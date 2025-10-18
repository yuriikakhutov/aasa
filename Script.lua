---@diagnostic disable: undefined-global, param-type-mismatch

local camera_lock = {}

--#region menu
local menu_root = Menu.Create("Utility", "Camera", "Lock On Click", "Umbrella")
local general_group = menu_root:Create("General")
local behaviour_group = menu_root:Create("Behaviour")

local ui = {
    enabled = general_group:Switch("Enable camera auto-lock", true),
    show_notifications = general_group:Switch("Show lock notifications", false),
    double_click_window = behaviour_group:Slider("Double-click window (ms)", 150, 600, 300, "%.0f"),
    release_threshold = behaviour_group:Slider("Manual release distance", 240, 900, 450, "%.0f"),
    update_interval = behaviour_group:Slider("Camera refresh interval (ms)", 10, 120, 30, "%.0f"),
    grace_period = behaviour_group:Slider("Release grace period (ms)", 100, 600, 350, "%.0f"),
}
--#endregion

--#region state
local state = {
    player = nil,
    lock_target = nil,
    lock_index = nil,
    lock_start_time = 0,
    next_camera_update = 0,
    last_follow_position = nil,
    camera_target_active = false,
    camera_target_last_seen = 0,
    selection_token = nil,
    last_click_index = nil,
    last_click_time = 0,
}

local const = {
    default_double_click_window = 0.35,
    default_release_threshold = 450.0,
    default_update_interval = 0.03,
    default_release_grace = 0.35,
    camera_target_timeout = 0.2,
}
--#endregion

--#region helpers
local function reset_state()
    state.player = nil
    state.lock_target = nil
    state.lock_index = nil
    state.lock_start_time = 0
    state.next_camera_update = 0
    state.last_follow_position = nil
    state.camera_target_active = false
    state.camera_target_last_seen = 0
    state.selection_token = nil
    state.last_click_index = nil
    state.last_click_time = 0
end

local function notify(message)
    if not ui.show_notifications:Get() then
        return
    end
    Notifications.AddBottom(message, 2.0)
end

local function current_time()
    local now = GameRules.GetGameTime()
    if now <= 0 then
        now = GlobalVars.GetAbsFrameTime()
    end
    return now
end

local function get_double_click_window()
    if ui.double_click_window then
        return math.max(0.05, ui.double_click_window:Get() * 0.001)
    end
    return const.default_double_click_window
end

local function get_release_threshold()
    if ui.release_threshold then
        return math.max(120.0, ui.release_threshold:Get())
    end
    return const.default_release_threshold
end

local function get_update_interval()
    if ui.update_interval then
        return math.max(0.01, ui.update_interval:Get() * 0.001)
    end
    return const.default_update_interval
end

local function get_release_grace()
    if ui.grace_period then
        return math.max(0.05, ui.grace_period:Get() * 0.001)
    end
    return const.default_release_grace
end

local function refresh_player()
    local player = Players.GetLocal()
    if player ~= state.player then
        state.player = player
        state.selection_token = nil
        state.last_click_index = nil
        state.last_click_time = 0
    end
    return state.player ~= nil
end

local function clear_lock()
    if state.lock_target then
        notify("Camera lock disabled")
    end

    state.lock_target = nil
    state.lock_index = nil
    state.lock_start_time = 0
    state.next_camera_update = 0
    state.last_follow_position = nil
end

local function center_camera_on(hero)
    if not hero then
        return
    end
    local pos = Entity.GetAbsOrigin(hero)
    if not pos then
        return
    end
    Engine.LookAt(pos.x, pos.y)
    state.last_follow_position = pos
end

local function lock_to_target(hero, index, now)
    if not hero or index == 0 then
        return
    end

    if state.lock_target and state.lock_index == index then
        clear_lock()
        return
    end

    state.lock_target = hero
    state.lock_index = index
    state.lock_start_time = now or current_time()
    state.next_camera_update = 0
    state.last_follow_position = nil

    notify("Camera locked")
    center_camera_on(hero)
end

local function build_selection_token(units)
    local indexes = {}
    for _, unit in pairs(units) do
        if unit then
            local idx = Entity.GetIndex(unit)
            if idx and idx > 0 then
                indexes[#indexes + 1] = idx
            end
        end
    end

    if #indexes == 0 then
        return nil
    end

    table.sort(indexes)
    return table.concat(indexes, ":")
end

local function find_primary_hero(units)
    local preferred = nil
    local fallback = nil

    for _, unit in pairs(units) do
        if unit and Entity.IsHero(unit) then
            if not fallback then
                fallback = unit
            end
            if not NPC.IsIllusion(unit) then
                preferred = unit
                break
            end
        end
    end

    return preferred or fallback
end

local function update_from_selection(now)
    local player = state.player
    if not player then
        return
    end

    local units = Player.GetSelectedUnits(player)
    if not units then
        state.selection_token = nil
        return
    end

    local token = build_selection_token(units)
    if not token then
        state.selection_token = nil
        return
    end

    if state.selection_token == token then
        return
    end

    state.selection_token = token

    local hero = find_primary_hero(units)
    if not hero then
        state.last_click_index = nil
        state.last_click_time = 0
        return
    end

    local hero_index = Entity.GetIndex(hero)
    if hero_index == 0 then
        return
    end

    local window = get_double_click_window()
    if state.last_click_index == hero_index and (now - state.last_click_time) <= window then
        lock_to_target(hero, hero_index, now)
        state.last_click_index = nil
        state.last_click_time = 0
    else
        state.last_click_index = hero_index
        state.last_click_time = now
    end
end

local function update_from_camera_target(now)
    if not state.player then
        return
    end

    local team_data = Player.GetTeamPlayer(state.player)
    if not team_data then
        state.camera_target_active = false
        return
    end

    local camera_target = team_data.camera_target
    if camera_target then
        local index = Entity.GetIndex(camera_target)
        if index and index > 0 then
            state.camera_target_active = true
            state.camera_target_last_seen = now
            lock_to_target(camera_target, index, now)
            return
        end
    end

    if state.camera_target_active and (now - state.camera_target_last_seen) > const.camera_target_timeout then
        state.camera_target_active = false
    end
end

local function should_release_due_to_manual_camera(now)
    local hero = state.lock_target
    if not hero then
        return false
    end

    if state.camera_target_active then
        return false
    end

    if (now - state.lock_start_time) <= get_release_grace() then
        return false
    end

    local camera_pos = Humanizer.GetClientCameraPos()
    if not camera_pos then
        return false
    end

    local hero_pos = Entity.GetAbsOrigin(hero)
    if not hero_pos then
        return true
    end

    local offset = (camera_pos - hero_pos):Length2D()
    return offset > get_release_threshold()
end

local function maintain_camera(now)
    local hero = state.lock_target
    if not hero then
        return
    end

    if not Entity.IsHero(hero) then
        clear_lock()
        return
    end

    if should_release_due_to_manual_camera(now) then
        clear_lock()
        return
    end

    if now < state.next_camera_update then
        return
    end

    state.next_camera_update = now + get_update_interval()

    local pos = Entity.GetAbsOrigin(hero)
    if not pos then
        clear_lock()
        return
    end

    Engine.LookAt(pos.x, pos.y)
    state.last_follow_position = pos
end
--#endregion

--#region callbacks
function camera_lock.OnUpdate()
    if not ui.enabled:Get() then
        if state.lock_target then
            clear_lock()
        end
        return
    end

    if not refresh_player() then
        if state.lock_target then
            clear_lock()
        end
        return
    end

    local now = current_time()

    update_from_camera_target(now)
    update_from_selection(now)
    maintain_camera(now)
end

function camera_lock.OnGameStart()
    reset_state()
end

camera_lock.OnGameEnd = reset_state
camera_lock.OnGameClose = reset_state

return camera_lock

