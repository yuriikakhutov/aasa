---@diagnostic disable: undefined-global

--[[
    Umbrella helper that double-clicks the currently selected hero portrait.
    Whenever the local player has a controllable hero selected and the camera
    is not locked on it, the script double-clicks the portrait to trigger the
    in-game camera lock behaviour.  After each attempt the script waits for a
    short cooldown before checking again.
--]]

local auto_lock = {}

local DOUBLE_CLICK_INTERVAL = 0.05
local CHECK_COOLDOWN = 2.0

local state = {
    player = nil,
    pending_target = nil,
    pending_click_stage = 0,
    next_click_time = 0,
    next_check_time = 0,
    locked_target = nil,
}

local function reset_state()
    state.pending_target = nil
    state.pending_click_stage = 0
    state.next_click_time = 0
    state.next_check_time = 0
    state.locked_target = nil
end

local function refresh_player()
    local player = state.player

    if player and Players.Contains(player) then
        return player
    end

    player = Players.GetLocal()
    state.player = player
    return player
end

local function is_valid_target(unit)
    if not unit or not Entity.IsHero(unit) then
        return false
    end

    if Entity.IsDormant(unit) or not Entity.IsAlive(unit) then
        return false
    end

    return true
end

local function first_selected_hero(player)
    local selected_units = Player.GetSelectedUnits(player)

    if not selected_units then
        return nil
    end

    for _, unit in ipairs(selected_units) do
        if is_valid_target(unit) then
            return unit
        end
    end

    return nil
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(fn, ...)
    if not ok then
        return false, nil
    end

    return true, result
end

local function current_camera_target(player)
    local getters = {
        function()
            local ok, value = safe_call(Players and Players.GetCameraTarget, player)
            if ok then
                return value
            end
        end,
        function()
            local ok, value = safe_call(Player and Player.GetCameraTarget, player)
            if ok then
                return value
            end
        end,
        function()
            local ok, value = safe_call(Engine and Engine.GetCameraTarget, player)
            if ok then
                return value
            end
        end,
        function()
            if type(Camera) == "table" then
                local ok, value = safe_call(Camera.GetTarget, player)
                if ok then
                    return value
                end
            end
        end,
    }

    for _, getter in ipairs(getters) do
        local value = getter()
        if value then
            return value
        end
    end

    return nil
end

local function is_camera_locked(player, hero)
    if not hero then
        return false
    end

    local checks = {
        function()
            local ok, value = safe_call(Players and Players.IsCameraLockedOnHero, player, hero)
            if ok then
                return value
            end
        end,
        function()
            local ok, value = safe_call(Player and Player.IsCameraLockedOnHero, player, hero)
            if ok then
                return value
            end
        end,
        function()
            local ok, value = safe_call(Engine and Engine.IsCameraLockedOnHero, hero)
            if ok then
                return value
            end
        end,
    }

    for _, check in ipairs(checks) do
        local result = check()
        if result ~= nil then
            return result
        end
    end

    local camera_target = current_camera_target(player)
    if camera_target then
        return camera_target == hero
    end

    return state.locked_target == hero
end

local function single_portrait_click(player, hero)
    local attempts = {
        function()
            local ok, result = safe_call(Players and Players.ClickHeroPortrait, player, hero)
            if ok then
                return result ~= false, false
            end
        end,
        function()
            local ok, result = safe_call(Player and Player.ClickHeroPortrait, player, hero)
            if ok then
                return result ~= false, false
            end
        end,
        function()
            local ok, result = safe_call(Players and Players.DoubleClickPortrait, player, hero)
            if ok then
                return result ~= false, true
            end
        end,
        function()
            local ok, result = safe_call(Player and Player.DoubleClickPortrait, player, hero)
            if ok then
                return result ~= false, true
            end
        end,
        function()
            if type(Engine) == "table" and type(Engine.ExecuteCommand) == "function" then
                local success = safe_call(Engine.ExecuteCommand, "dota_camera_lock 1")
                return success, true
            end
        end,
    }

    for _, attempt in ipairs(attempts) do
        local success, completed = attempt()
        if success ~= nil then
            if success then
                return true, completed or false
            end
        end
    end

    return false, false
end

local function start_double_click(hero, current_time)
    state.pending_target = hero
    state.pending_click_stage = 0
    state.next_click_time = current_time
end

local function process_double_click(player, current_time)
    if not state.pending_target then
        return false
    end

    if current_time < state.next_click_time then
        return true
    end

    local hero = state.pending_target
    if not is_valid_target(hero) then
        state.pending_target = nil
        state.pending_click_stage = 0
        return false
    end

    local success, completed = single_portrait_click(player, hero)
    if success then
        state.pending_click_stage = state.pending_click_stage + 1
        if completed or state.pending_click_stage >= 2 then
            state.locked_target = hero
            state.pending_target = nil
            state.pending_click_stage = 0
            state.next_check_time = current_time + CHECK_COOLDOWN
            return false
        else
            state.next_click_time = current_time + DOUBLE_CLICK_INTERVAL
            return true
        end
    else
        state.pending_target = nil
        state.pending_click_stage = 0
        state.next_check_time = current_time + CHECK_COOLDOWN
        return false
    end
end

function auto_lock.OnUpdate()
    if not Engine.IsInGame() then
        reset_state()
        state.player = nil
        return
    end

    if Input.IsInputCaptured() then
        return
    end

    local player = refresh_player()
    if not player then
        reset_state()
        return
    end

    local current_time = GameRules.GetGameTime()

    if process_double_click(player, current_time) then
        return
    end

    local camera_target = current_camera_target(player)
    if camera_target and camera_target ~= state.locked_target then
        state.locked_target = camera_target
    elseif not camera_target and not state.pending_target then
        state.locked_target = nil
    end

    if current_time < state.next_check_time then
        return
    end

    local hero = first_selected_hero(player)
    if not hero then
        state.locked_target = nil
        return
    end

    if not is_camera_locked(player, hero) then
        start_double_click(hero, current_time)
    else
        state.locked_target = hero
        state.next_check_time = current_time + CHECK_COOLDOWN
    end
end

return auto_lock
