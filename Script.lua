---@diagnostic disable: undefined-global

--[[
    Umbrella helper that mimics a constant portrait double click.
    Whenever the player selects a hero that is not already being followed
    the script snaps and keeps the camera locked on that hero automatically.
--]]

local auto_lock = {}

local state = {
    player = nil,
    follow_target = nil,
    last_camera_update = 0,
}

local function reset_follow()
    state.follow_target = nil
    state.last_camera_update = 0
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

local function lock_camera_on(target)
    state.follow_target = target
    state.last_camera_update = 0

    local position = Entity.GetAbsOrigin(target)
    Engine.LookAt(position.x, position.y)
    state.last_camera_update = GameRules.GetGameTime()
end

function auto_lock.OnUpdate()
    if not Engine.IsInGame() then
        reset_follow()
        state.player = nil
        return
    end

    if Input.IsInputCaptured() then
        return
    end

    local player = refresh_player()
    if not player then
        reset_follow()
        return
    end

    local selected_hero = first_selected_hero(player)

    if selected_hero and selected_hero ~= state.follow_target then
        lock_camera_on(selected_hero)
    elseif not selected_hero and state.follow_target then
        reset_follow()
        return
    end

    local target = state.follow_target
    if not target then
        return
    end

    if not is_valid_target(target) then
        reset_follow()
        return
    end

    local game_time = GameRules.GetGameTime()
    if game_time - state.last_camera_update < 0.03 then
        return
    end

    local position = Entity.GetAbsOrigin(target)
    Engine.LookAt(position.x, position.y)
    state.last_camera_update = game_time
end

return auto_lock
