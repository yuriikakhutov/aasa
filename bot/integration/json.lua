local M = {}

local function decode_error(str, idx, msg)
    error(string.format("JSON decode error at position %d: %s\n%s", idx, msg or "", str))
end

local function skip_whitespace(str, idx)
    local len = #str
    while idx <= len do
        local c = string.sub(str, idx, idx)
        if c ~= ' ' and c ~= '\n' and c ~= '\r' and c ~= '\t' then
            break
        end
        idx = idx + 1
    end
    return idx
end

local function parse_literal(str, idx, literal, value)
    if string.sub(str, idx, idx + #literal - 1) ~= literal then
        decode_error(str, idx, "expected '" .. literal .. "'")
    end
    return value, idx + #literal
end

local function parse_number(str, idx)
    local start_idx = idx
    local len = #str
    local has_exp = false
    local has_dot = false
    if string.sub(str, idx, idx) == '-' then
        idx = idx + 1
    end
    while idx <= len do
        local c = string.sub(str, idx, idx)
        if c >= '0' and c <= '9' then
            idx = idx + 1
        else
            break
        end
    end
    if string.sub(str, idx, idx) == '.' then
        has_dot = true
        idx = idx + 1
        while idx <= len do
            local c = string.sub(str, idx, idx)
            if c >= '0' and c <= '9' then
                idx = idx + 1
            else
                break
            end
        end
    end
    local c = string.sub(str, idx, idx)
    if c == 'e' or c == 'E' then
        has_exp = true
        idx = idx + 1
        c = string.sub(str, idx, idx)
        if c == '+' or c == '-' then
            idx = idx + 1
        end
        while idx <= len do
            c = string.sub(str, idx, idx)
            if c >= '0' and c <= '9' then
                idx = idx + 1
            else
                break
            end
        end
    end
    local number_str = string.sub(str, start_idx, idx - 1)
    local value = tonumber(number_str)
    if value == nil then
        decode_error(str, start_idx, "invalid number")
    end
    return value, idx
end

local function parse_string(str, idx)
    idx = idx + 1 -- skip opening quote
    local len = #str
    local result = {}
    while idx <= len do
        local c = string.sub(str, idx, idx)
        if c == '"' then
            return table.concat(result), idx + 1
        elseif c == '\\' then
            idx = idx + 1
            c = string.sub(str, idx, idx)
            if c == '"' or c == '\\' or c == '/' then
                table.insert(result, c)
            elseif c == 'b' then
                table.insert(result, '\b')
            elseif c == 'f' then
                table.insert(result, '\f')
            elseif c == 'n' then
                table.insert(result, '\n')
            elseif c == 'r' then
                table.insert(result, '\r')
            elseif c == 't' then
                table.insert(result, '\t')
            elseif c == 'u' then
                local hex = string.sub(str, idx + 1, idx + 4)
                if not hex:match("^[0-9a-fA-F]+$") then
                    decode_error(str, idx, "invalid unicode escape")
                end
                idx = idx + 4
                local code = tonumber(hex, 16)
                if code then
                    if code <= 0x7F then
                        table.insert(result, string.char(code))
                    elseif code <= 0x7FF then
                        local b1 = 0xC0 + math.floor(code / 0x40)
                        local b2 = 0x80 + (code % 0x40)
                        table.insert(result, string.char(b1, b2))
                    elseif code <= 0xFFFF then
                        local b1 = 0xE0 + math.floor(code / 0x1000)
                        local b2 = 0x80 + math.floor((code % 0x1000) / 0x40)
                        local b3 = 0x80 + (code % 0x40)
                        table.insert(result, string.char(b1, b2, b3))
                    else
                        local b1 = 0xF0 + math.floor(code / 0x40000)
                        local b2 = 0x80 + math.floor((code % 0x40000) / 0x1000)
                        local b3 = 0x80 + math.floor((code % 0x1000) / 0x40)
                        local b4 = 0x80 + (code % 0x40)
                        table.insert(result, string.char(b1, b2, b3, b4))
                    end
                else
                    decode_error(str, idx, "invalid unicode escape value")
                end
            else
                decode_error(str, idx, "invalid escape character")
            end
        else
            table.insert(result, c)
        end
        idx = idx + 1
    end
    decode_error(str, idx, "unterminated string")
end

local function parse_array(str, idx)
    idx = idx + 1 -- skip [
    local array = {}
    idx = skip_whitespace(str, idx)
    if string.sub(str, idx, idx) == ']' then
        return array, idx + 1
    end
    while true do
        local value
        value, idx = M.decode_internal(str, idx)
        table.insert(array, value)
        idx = skip_whitespace(str, idx)
        local c = string.sub(str, idx, idx)
        if c == ',' then
            idx = idx + 1
            idx = skip_whitespace(str, idx)
        elseif c == ']' then
            return array, idx + 1
        else
            decode_error(str, idx, "expected ',' or ']' in array")
        end
    end
end

local function parse_object(str, idx)
    idx = idx + 1 -- skip {
    local object = {}
    idx = skip_whitespace(str, idx)
    if string.sub(str, idx, idx) == '}' then
        return object, idx + 1
    end
    while true do
        if string.sub(str, idx, idx) ~= '"' then
            decode_error(str, idx, "expected string key")
        end
        local key
        key, idx = parse_string(str, idx)
        idx = skip_whitespace(str, idx)
        if string.sub(str, idx, idx) ~= ':' then
            decode_error(str, idx, "expected ':' after key")
        end
        idx = skip_whitespace(str, idx + 1)
        local value
        value, idx = M.decode_internal(str, idx)
        object[key] = value
        idx = skip_whitespace(str, idx)
        local c = string.sub(str, idx, idx)
        if c == ',' then
            idx = skip_whitespace(str, idx + 1)
        elseif c == '}' then
            return object, idx + 1
        else
            decode_error(str, idx, "expected ',' or '}' in object")
        end
    end
end

function M.decode_internal(str, idx)
    idx = skip_whitespace(str, idx)
    local c = string.sub(str, idx, idx)
    if c == '"' then
        return parse_string(str, idx)
    elseif c == '{' then
        return parse_object(str, idx)
    elseif c == '[' then
        return parse_array(str, idx)
    elseif c == '-' or c:match("%d") then
        return parse_number(str, idx)
    elseif c == 't' then
        return parse_literal(str, idx, "true", true)
    elseif c == 'f' then
        return parse_literal(str, idx, "false", false)
    elseif c == 'n' then
        return parse_literal(str, idx, "null", nil)
    elseif c == '' then
        decode_error(str, idx, "unexpected end of input")
    end
    decode_error(str, idx, "unexpected character '" .. c .. "'")
end

function M.decode(str)
    local value, idx = M.decode_internal(str, 1)
    idx = skip_whitespace(str, idx)
    if idx <= #str then
        decode_error(str, idx, "unexpected trailing characters")
    end
    return value
end

function M.load(path)
    local file, err = io.open(path, "r")
    if not file then
        error("Failed to open JSON file '" .. path .. "': " .. tostring(err))
    end
    local content = file:read("*a")
    file:close()
    return M.decode(content)
end

return M
