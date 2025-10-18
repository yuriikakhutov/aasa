---
-- Runtime assertions used by tests and profiling to guarantee safety bars.
---

local Validators = {}

local baselineGlobals = {}

do
    local ok, env = pcall(function()
        return getfenv(0)
    end)
    if ok and type(env) == "table" then
        for k in pairs(env) do
            baselineGlobals[k] = true
        end
    end
end

local function deltaSeconds(a, b)
    return math.abs((a or 0) - (b or 0))
end

function Validators.assert_no_spam_orders(history)
    local lastPerType = {}
    for _, order in ipairs(history or {}) do
        local prev = lastPerType[order.kind]
        if prev then
            if deltaSeconds(order.time, prev.time) < 0.12 then
                error("Order spam detected for " .. tostring(order.kind))
            end
            if order.signature ~= nil and prev.signature ~= nil and order.signature == prev.signature then
                error("Duplicate consecutive order signature for " .. tostring(order.kind))
            end
        end
        lastPerType[order.kind] = order
    end
end

function Validators.assert_no_globals()
    local ok, env = pcall(function()
        return getfenv(0)
    end)
    if not ok or type(env) ~= "table" then
        return
    end
    for k in pairs(env) do
        if not baselineGlobals[k] then
            error("Unexpected global detected: " .. tostring(k))
        end
    end
end

function Validators.assert_timer_granularity(settings)
    if not settings then
        return
    end
    local high = settings.tickHigh or 0
    local combat = settings.tickCombat or 0
    if high < 0.12 or high > 0.2 then
        error("High-level tick outside allowed range")
    end
    if combat < 0.03 or combat > 0.06 then
        error("Combat tick outside allowed range")
    end
end

local function isDangerousTower(tower)
    if not tower or not tower.tier then
        return false
    end
    return tower.tier >= 3
end

function Validators.assert_pathing_safety(path, towers)
    if not path or not path.waypoints then
        return
    end
    for _, tower in ipairs(towers or {}) do
        if isDangerousTower(tower) then
            for _, wp in ipairs(path.waypoints) do
                local dx = (tower.pos.x or 0) - (wp.x or 0)
                local dy = (tower.pos.y or 0) - (wp.y or 0)
                if math.sqrt(dx * dx + dy * dy) < (tower.radius or 800) then
                    error("Path enters high-tier tower radius")
                end
            end
        end
    end
end

function Validators.assert_abilities_no_passives(abilities)
    for _, ability in ipairs(abilities or {}) do
        if ability.isPassive or ability.behavior == "PASSIVE" then
            error("Passive ability scheduled for casting: " .. tostring(ability.name))
        end
    end
end

function Validators.assert_rubick_no_blink_misuse(records)
    for _, record in ipairs(records or {}) do
        if record.usedBlink and record.safeCastRange and record.safeCastRange > record.blinkRange then
            error("Rubick blink misuse detected")
        end
        if record.usedBlink and record.dangerScore and record.dangerScore > 0.7 then
            error("Rubick blinked into dangerous zone")
        end
    end
end

local function countLineStats(path)
    local file = io.open(path, "r")
    if not file then
        return 0, 0, 0
    end
    local code, comment, blank = 0, 0, 0
    for line in file:lines() do
        if line:match("^%s*$") then
            blank = blank + 1
        elseif line:match("^%s*%-%-") then
            comment = comment + 1
        else
            code = code + 1
        end
    end
    file:close()
    return code, comment, blank
end

function Validators.count_code_lines(root)
    local cmd = string.format("find %s -type f -name '*.lua'", root)
    local handle = io.popen(cmd)
    if not handle then
        return { code = 0, comment = 0, blank = 0 }
    end
    local total = { code = 0, comment = 0, blank = 0 }
    for path in handle:lines() do
        local c, m, b = countLineStats(path)
        total.code = total.code + c
        total.comment = total.comment + m
        total.blank = total.blank + b
    end
    handle:close()
    return total
end

function Validators.assert_code_volume(root, minimum)
    local stats = Validators.count_code_lines(root)
    if stats.code < minimum then
        error(string.format("Code volume %d below minimum %d", stats.code, minimum))
    end
    return stats
end

return Validators

