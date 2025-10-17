local Log = Log or { Write = function(msg) print(tostring(msg)) end }

local M = {
    config = {
        logLevel = "INFO",
        debug = false,
        logLimitPerTick = 10,
    },
    _logWeights = {
        ERROR = 4,
        WARN = 3,
        INFO = 2,
        DEBUG = 1,
    },
    _lastTickBucket = -1,
    _tickLogCount = 0,
}

local function ensure_vector(v)
    if type(v) == "userdata" or type(v) == "table" then
        return v
    end
    error("expected Vector, got " .. type(v))
end

function M.init(config)
    if type(config) == "table" then
        for k, v in pairs(config) do
            M.config[k] = v
        end
    end
end

function M.tick_reset(game_time)
    local bucket = math.floor((game_time or 0) * 10)
    if bucket ~= M._lastTickBucket then
        M._lastTickBucket = bucket
        M._tickLogCount = 0
    end
end

local function should_log(level)
    local target = M._logWeights[string.upper(M.config.logLevel or "INFO")] or 2
    local value = M._logWeights[string.upper(level)] or target
    return value >= target or M.config.debug
end

local function trim_message(msg)
    if type(msg) == "table" then
        local parts = {}
        for k, v in pairs(msg) do
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
        table.sort(parts)
        return table.concat(parts, ", ")
    end
    return tostring(msg)
end

function M.log(level, msg)
    level = string.upper(level or "INFO")
    if not should_log(level) then
        return
    end
    if M._tickLogCount >= (M.config.logLimitPerTick or 10) then
        return
    end
    M._tickLogCount = M._tickLogCount + 1
    local prefix = string.format("[%s] ", level)
    Log.Write(prefix .. trim_message(msg))
end

function M.debug(msg)
    if M.config.debug then
        M.log("DEBUG", msg)
    end
end

function M.clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    elseif value > max_value then
        return max_value
    end
    return value
end

function M.lerp(a, b, t)
    return a + (b - a) * t
end

function M.distance(a, b)
    ensure_vector(a)
    ensure_vector(b)
    if a.Distance then
        return a:Distance(b)
    end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function M.distance2d(a, b)
    ensure_vector(a)
    ensure_vector(b)
    if a.Distance2D then
        return a:Distance2D(b)
    end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function M.normalize(vec)
    ensure_vector(vec)
    if vec.Normalized then
        return vec:Normalized()
    end
    local len = math.sqrt((vec.x or 0) ^ 2 + (vec.y or 0) ^ 2 + (vec.z or 0) ^ 2)
    if len == 0 then
        return Vector(0, 0, 0)
    end
    return Vector((vec.x or 0) / len, (vec.y or 0) / len, (vec.z or 0) / len)
end

function M.project(from, to, distance)
    local direction = M.normalize(to - from)
    return from + direction * distance
end

function M.shallow_copy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

function M.deep_copy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = M.deep_copy(v)
    end
    return copy
end

function M.average(values)
    local sum = 0
    local count = 0
    for _, v in pairs(values) do
        sum = sum + v
        count = count + 1
    end
    if count == 0 then
        return 0
    end
    return sum / count
end

function M.max_value(values)
    local max_v = nil
    local max_k = nil
    for k, v in pairs(values) do
        if max_v == nil or v > max_v then
            max_v = v
            max_k = k
        end
    end
    return max_k, max_v
end

function M.sum(values, selector)
    local total = 0
    for _, v in pairs(values) do
        if selector then
            total = total + selector(v)
        else
            total = total + v
        end
    end
    return total
end

function M.safe_call(func, ...)
    local ok, res = pcall(func, ...)
    if not ok then
        M.log("ERROR", "Safe call failed: " .. tostring(res))
        return nil
    end
    return res
end

return M
