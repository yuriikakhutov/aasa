---@diagnostic disable: undefined-global

local portrait_lock = {}

local settings_group = Menu.Create("Utility", "Camera", "Camera Tools", "Portrait Lock")

local ui = {
    enabled = settings_group:Switch("Enable portrait camera follow", true),
    double_click = settings_group:Slider("Double-click window (ms)", 325, 150, 600, "%.0f ms"),
    update_rate = settings_group:Slider("Camera update interval (ms)", 45, 16, 120, "%.0f ms"),
    hold_unlock = settings_group:Bind("Hold to suspend camera follow", Enum.ButtonCode.KEY_NONE),
    toggle_bind = settings_group:Bind("Toggle follow for selected unit", Enum.ButtonCode.KEY_NONE),
}

local state = {
    player = nil,
    pending_index = nil,
    pending_time = 0,
    lock_index = nil,
    next_camera_update = 0,
    hold_active = false,
    last_camera_target_index = nil,
}

local function reset_state()
    state.pending_index = nil
    state.pending_time = 0
    state.lock_index = nil
    state.next_camera_update = 0
    state.hold_active = false
    state.last_camera_target_index = nil
end

local function refresh_player()
    local player = Players.GetLocal()
    if player ~= state.player then
        state.player = player
        state.pending_index = nil
        state.pending_time = 0
    end
    return player ~= nil
end

local function resolve_target(index)
    if not index then
        return nil
    end
    local entity = Entity.Get(index)
    if entity and Entity.IsEntity(entity) then
        return entity
    end
    return nil
end

local function get_selected_hero()
    if not state.player then
        return nil
    end
    local units = Player.GetSelectedUnits(state.player)
    if not units then
        return nil
    end
    for _, unit in pairs(units) do
        if Entity.IsHero(unit) then
            if Hero and Hero.GetReplicatingOtherHeroModel then
                local original = Hero.GetReplicatingOtherHeroModel(unit)
                if original then
                    return original
                end
            end
            return unit
        end
    end
    return nil
end

local function clear_lock()
    if state.lock_index then
        state.lock_index = nil
        state.next_camera_update = 0
        state.hold_active = false
    end
end

local function apply_lock(hero)
    if not hero or not Entity.IsHero(hero) then
        return
    end
    state.lock_index = Entity.GetIndex(hero)
    state.next_camera_update = 0
    state.hold_active = false
    state.last_camera_target_index = state.lock_index

    Engine.ExecuteCommand("dota_camera_lock 0")
    Engine.ExecuteCommand("dota_camera_lock_tether_to_hero 0")

    local origin = Entity.GetAbsOrigin(hero)
    if origin then
        Engine.LookAt(origin.x, origin.y)
    end
end

local function handle_manual_toggle()
    if not ui.toggle_bind then
        return
    end
    if ui.toggle_bind:IsPressed() then
        if state.lock_index then
            clear_lock()
        else
            local hero = get_selected_hero()
            if hero then
                apply_lock(hero)
            end
        end
    end
end

local function handle_double_click(now)
    if Menu.Opened() then
        return
    end
    if not Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then
        return
    end
    if Input.IsInputCaptured() then
        return
    end

    local hero = get_selected_hero()
    if not hero then
        state.pending_index = nil
        state.pending_time = 0
        return
    end

    local index = Entity.GetIndex(hero)
    if not index or index <= 0 then
        return
    end

    local threshold = ui.double_click:Get() / 1000.0
    if state.pending_index == index and (now - state.pending_time) <= threshold then
        if state.lock_index == index then
            clear_lock()
        else
            apply_lock(hero)
        end
        state.pending_index = nil
        state.pending_time = 0
        return
    end

    state.pending_index = index
    state.pending_time = now
end

local function update_camera(now)
    if not state.lock_index then
        return
    end

    local bind = ui.hold_unlock
    if bind and bind:IsDown() then
        state.hold_active = true
        return
    elseif state.hold_active then
        state.hold_active = false
        state.next_camera_update = 0
    end

    local target = resolve_target(state.lock_index)
    if not target or not Entity.IsHero(target) then
        clear_lock()
        return
    end

    local interval = ui.update_rate:Get() / 1000.0
    if now < state.next_camera_update then
        return
    end

    local origin = Entity.GetAbsOrigin(target)
    if not origin then
        return
    end

    Engine.LookAt(origin.x, origin.y)
    state.next_camera_update = now + interval
end

function portrait_lock.OnGameStart()
    reset_state()
end

function portrait_lock.OnGameEnd()
    reset_state()
end

function portrait_lock.OnScriptLoad()
    reset_state()
end

function portrait_lock.OnScriptUnload()
    reset_state()
end

local function sync_with_camera_target()
    local data = Player.GetTeamPlayer and state.player and Player.GetTeamPlayer(state.player)
    if not data then
        state.last_camera_target_index = nil
        return
    end

    local target = data.camera_target
    local index = nil

    if target and Entity.IsHero(target) then
        index = Entity.GetIndex(target)
        if not index or index <= 0 then
            index = nil
        elseif state.lock_index ~= index and state.last_camera_target_index ~= index then
            apply_lock(target)
        end
    end

    state.last_camera_target_index = index
end

function portrait_lock.OnUpdate()
    if not ui.enabled:Get() then
        clear_lock()
        return
    end

    if not refresh_player() then
        clear_lock()
        return
    end

    local now = GameRules.GetGameTime() or 0

    handle_manual_toggle()
    handle_double_click(now)
    sync_with_camera_target()
    update_camera(now)
end

return portrait_lock
