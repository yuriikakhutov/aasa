local Log = Log or { Write = function(msg) print(tostring(msg)) end }

local fallbackVectorMt

if type(_G.Vector) ~= "function" then
    local function component(tbl, key, index)
        if type(tbl) ~= "table" then
            return 0
        end
        local value = tbl[key]
        if value == nil and index then
            value = tbl[index]
        end
        if type(value) == "number" then
            return value
        end
        return 0
    end

    local function fallback_components(vec)
        if type(vec) ~= "table" then
            return 0, 0, 0
        end
        return component(vec, "x", 1), component(vec, "y", 2), component(vec, "z", 3)
    end

    local function fallback_vector(x, y, z)
        return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, fallbackVectorMt)
    end

    local function fallback_add(a, b)
        local ax, ay, az = fallback_components(a)
        local bx, by, bz = fallback_components(b)
        return fallback_vector(ax + bx, ay + by, az + bz)
    end

    local function fallback_sub(a, b)
        local ax, ay, az = fallback_components(a)
        local bx, by, bz = fallback_components(b)
        return fallback_vector(ax - bx, ay - by, az - bz)
    end

    local function fallback_scale(v, scalar)
        local x, y, z = fallback_components(v)
        return fallback_vector(x * scalar, y * scalar, z * scalar)
    end

    local function fallback_length(v)
        local x, y, z = fallback_components(v)
        return math.sqrt(x * x + y * y + z * z)
    end

    local function fallback_length2d(v)
        local x, y = fallback_components(v)
        return math.sqrt(x * x + y * y)
    end

    fallbackVectorMt = {
        __add = fallback_add,
        __sub = fallback_sub,
        __mul = function(a, b)
            if type(a) == "number" then
                return fallback_scale(b, a)
            elseif type(b) == "number" then
                return fallback_scale(a, b)
            end
            return fallback_vector(0, 0, 0)
        end,
        __tostring = function(v)
            local x, y, z = fallback_components(v)
            return string.format("Vector(%.1f, %.1f, %.1f)", x, y, z)
        end,
    }

    fallbackVectorMt.__index = {
        Length = fallback_length,
        Length2D = fallback_length2d,
        Distance = function(self, other)
            return fallback_length(fallback_sub(self, other))
        end,
        Distance2D = function(self, other)
            return fallback_length2d(fallback_sub(self, other))
        end,
        Normalized = function(self)
            local len = fallback_length(self)
            if len == 0 then
                return fallback_vector(0, 0, 0)
            end
            local x, y, z = fallback_components(self)
            return fallback_vector(x / len, y / len, z / len)
        end,
        Clone = function(self)
            local x, y, z = fallback_components(self)
            return fallback_vector(x, y, z)
        end,
    }

    _G.Vector = function(x, y, z)
        return fallback_vector(x, y, z)
    end
end

local function safe_component(obj, key)
    local ok, value = pcall(function()
        local field = obj[key]
        if type(field) == "function" then
            return field(obj)
        end
        return field
    end)
    if ok and type(value) == "number" then
        return value
    end
    local methodName = "Get" .. string.upper(key)
    local okMethod, method = pcall(function()
        return obj[methodName]
    end)
    if okMethod and type(method) == "function" then
        local okCall, result = pcall(method, obj)
        if okCall and type(result) == "number" then
            return result
        end
    end
    return nil
end

local function vector_components(vec)
    if vec == nil then
        return 0, 0, 0
    end
    local t = type(vec)
    if t == "table" then
        local x = vec.x
        local y = vec.y
        local z = vec.z
        if x == nil then
            x = vec[1]
        end
        if y == nil then
            y = vec[2]
        end
        if z == nil then
            z = vec[3]
        end
        return x or 0, y or 0, z or 0
    elseif t == "userdata" then
        local x = safe_component(vec, "x")
        local y = safe_component(vec, "y")
        local z = safe_component(vec, "z")
        return x or 0, y or 0, z or 0
    end
    return 0, 0, 0
end

local function make_vector(x, y, z)
    local ok, result = pcall(Vector, x or 0, y or 0, z or 0)
    if ok and result ~= nil then
        return result
    end
    return { x = x or 0, y = y or 0, z = z or 0 }
end

local function ensure_vector(v)
    if v == nil then
        return make_vector(0, 0, 0)
    end
    local t = type(v)
    if t == "userdata" then
        return v
    elseif t == "table" then
        local mt = getmetatable(v)
        if mt ~= nil then
            return v
        end
        local x, y, z = vector_components(v)
        return make_vector(x, y, z)
    end
    error("expected Vector, got " .. t)
end

local function try_operator(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return nil
end

local function vector_add(a, b)
    local av = ensure_vector(a)
    local bv = ensure_vector(b)
    local result = try_operator(function()
        return av + bv
    end)
    if result ~= nil then
        return result
    end
    local ax, ay, az = vector_components(av)
    local bx, by, bz = vector_components(bv)
    return make_vector(ax + bx, ay + by, az + bz)
end

local function vector_sub(a, b)
    local av = ensure_vector(a)
    local bv = ensure_vector(b)
    local result = try_operator(function()
        return av - bv
    end)
    if result ~= nil then
        return result
    end
    local ax, ay, az = vector_components(av)
    local bx, by, bz = vector_components(bv)
    return make_vector(ax - bx, ay - by, az - bz)
end

local function vector_scale(vec, scalar)
    local v = ensure_vector(vec)
    local result = try_operator(function()
        return v * scalar
    end)
    if result ~= nil then
        return result
    end
    local x, y, z = vector_components(v)
    return make_vector(x * scalar, y * scalar, z * scalar)
end

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
    local av = ensure_vector(a)
    local bv = ensure_vector(b)
    if av and av.Distance then
        local ok, result = pcall(av.Distance, av, bv)
        if ok and type(result) == "number" then
            return result
        end
    end
    local ax, ay, az = vector_components(av)
    local bx, by, bz = vector_components(bv)
    local dx = ax - bx
    local dy = ay - by
    local dz = az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function M.distance2d(a, b)
    local av = ensure_vector(a)
    local bv = ensure_vector(b)
    if av and av.Distance2D then
        local ok, result = pcall(av.Distance2D, av, bv)
        if ok and type(result) == "number" then
            return result
        end
    end
    local ax, ay = vector_components(av)
    local bx, by = vector_components(bv)
    local dx = ax - bx
    local dy = ay - by
    return math.sqrt(dx * dx + dy * dy)
end

function M.normalize(vec)
    local v = ensure_vector(vec)
    if v and v.Normalized then
        local ok, result = pcall(v.Normalized, v)
        if ok and result ~= nil then
            return result
        end
    end
    local x, y, z = vector_components(v)
    local length = math.sqrt(x * x + y * y + z * z)
    if length == 0 then
        return make_vector(0, 0, 0)
    end
    return make_vector(x / length, y / length, z / length)
end

function M.project(from, to, distance)
    local origin = ensure_vector(from)
    local target = ensure_vector(to)
    local direction = M.normalize(vector_sub(target, origin))
    return vector_add(origin, vector_scale(direction, distance))
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

M.make_vector = make_vector
M.ensure_vector = ensure_vector
M.vector_add = vector_add
M.vector_sub = vector_sub
M.vector_scale = vector_scale
M.vector_components = vector_components

return M
