---@diagnostic disable: undefined-global

--[[
    Umbrella helper that issues an attack-move command at the mouse cursor
    whenever the left mouse button is clicked.  The script keeps the logic
    intentionally small and avoids extra configuration.
]]

local script = {}

local BUTTON_LEFT = nil
if Enum and Enum.ButtonCode then
    BUTTON_LEFT = Enum.ButtonCode.BUTTON_CODE_MOUSE_LEFT
        or Enum.ButtonCode.MOUSE_LEFT
        or Enum.ButtonCode.BUTTON_CODE_MOUSE_1
        or Enum.ButtonCode.MOUSE1
        or Enum.ButtonCode.KEY_LBUTTON
end

local ATTACK_MOVE_ORDER = Enum and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE
local HERO_ONLY_ISSUER = Enum and Enum.PlayerOrderIssuer and Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY

local state = {
    player = nil,
    hero = nil,
    button_down = false,
}

local function reset_state()
    state.player = nil
    state.hero = nil
    state.button_down = false
end

local function refresh_handles()
    if not Players or not Heroes then
        return false
    end

    if not state.player or (Players.Contains and not Players.Contains(state.player)) then
        state.player = Players.GetLocal and Players.GetLocal() or nil
    end

    if not state.hero or (Entity and not Entity.IsAlive(state.hero)) then
        state.hero = Heroes.GetLocal and Heroes.GetLocal() or nil
    end

    return state.player ~= nil and state.hero ~= nil
end

local function issue_attack_move()
    if not ATTACK_MOVE_ORDER or not HERO_ONLY_ISSUER then
        return
    end

    if not refresh_handles() then
        return
    end

    if not Input or not Input.GetWorldCursorPos then
        return
    end

    local cursor = Input.GetWorldCursorPos()
    if not cursor then
        return
    end

    if not Player or not Player.PrepareUnitOrders then
        return
    end

    Player.PrepareUnitOrders(
        state.player,
        ATTACK_MOVE_ORDER,
        nil,
        cursor,
        nil,
        HERO_ONLY_ISSUER,
        state.hero
    )
end

function script.OnUpdate()
    if not BUTTON_LEFT then
        return
    end

    if not Input then
        return
    end

    local pressed = false
    local is_down = false
    if Input.IsButtonDownOnce then
        pressed = Input.IsButtonDownOnce(BUTTON_LEFT)
        if Input.IsButtonDown then
            is_down = Input.IsButtonDown(BUTTON_LEFT)
        end
    elseif Input.IsButtonDown then
        is_down = Input.IsButtonDown(BUTTON_LEFT)
        pressed = is_down and not state.button_down or false
    else
        return
    end

    state.button_down = is_down

    if pressed then
        issue_attack_move()
    end
end

function script.OnScriptLoad()
    reset_state()
end

function script.OnScriptUnload()
    reset_state()
end

function script.OnGameStart()
    reset_state()
end

function script.OnGameEnd()
    reset_state()
end

return script

