local util = {}

local function decode_value(str)
  str = str:gsub("^%s+", "")
  if str:sub(1, 1) == '"' then
    local i = 2
    local buf = {}
    while i <= #str do
      local c = str:sub(i, i)
      if c == '"' then
        return table.concat(buf), str:sub(i + 1)
      elseif c == '\\' then
        local next_char = str:sub(i + 1, i + 1)
        if next_char == '"' or next_char == '\\' then
          table.insert(buf, next_char)
          i = i + 2
        elseif next_char == 'n' then
          table.insert(buf, "\n")
          i = i + 2
        else
          table.insert(buf, next_char)
          i = i + 2
        end
      else
        table.insert(buf, c)
        i = i + 1
      end
    end
    error("unterminated string in config.json")
  elseif str:sub(1, 1) == '{' then
    local result = {}
    local rest = str:sub(2)
    rest = rest:gsub("^%s+", "")
    if rest:sub(1, 1) == '}' then
      return result, rest:sub(2)
    end
    while true do
      local key
      key, rest = decode_value(rest)
      rest = rest:gsub("^%s*:%s*", "")
      local value
      value, rest = decode_value(rest)
      result[key] = value
      rest = rest:gsub("^%s*", "")
      local sep = rest:sub(1, 1)
      if sep == '}' then
        return result, rest:sub(2)
      elseif sep == ',' then
        rest = rest:sub(2)
      else
        error("invalid JSON object syntax near '" .. rest .. "'")
      end
    end
  elseif str:sub(1, 1) == '[' then
    local arr = {}
    local rest = str:sub(2)
    rest = rest:gsub("^%s+", "")
    if rest:sub(1, 1) == ']' then
      return arr, rest:sub(2)
    end
    local idx = 1
    while true do
      local value
      value, rest = decode_value(rest)
      arr[idx] = value
      idx = idx + 1
      rest = rest:gsub("^%s*", "")
      local sep = rest:sub(1, 1)
      if sep == ']' then
        return arr, rest:sub(2)
      elseif sep == ',' then
        rest = rest:sub(2)
      else
        error("invalid JSON array syntax near '" .. rest .. "'")
      end
    end
  else
    local literals = {
      ["true"] = true,
      ["false"] = false,
      ["null"] = nil,
    }
    for literal, value in pairs(literals) do
      if str:sub(1, #literal) == literal then
        return value, str:sub(#literal + 1)
      end
    end
    local number = str:match("^-?%d+%.?%d*[eE]?%-?%d*")
    if number then
      return tonumber(number), str:sub(#number + 1)
    end
  end
  error("unsupported JSON token near '" .. str .. "'")
end

function util.load_json(path)
  local file, err = io.open(path, "r")
  if not file then
    return nil, err
  end
  local content = file:read("*a")
  file:close()
  local result, rest = decode_value(content)
  rest = rest:gsub("^%s+", "")
  if #rest > 0 then
    error("unexpected trailing data in JSON: " .. rest)
  end
  return result
end

function util.clamp(value, min_val, max_val)
  if value < min_val then
    return min_val
  elseif value > max_val then
    return max_val
  end
  return value
end

function util.length2D(vec)
  return math.sqrt(vec.x * vec.x + vec.y * vec.y)
end

function util.distance2D(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

function util.normalize2D(vec)
  local len = util.length2D(vec)
  if len == 0 then
    return { x = 0, y = 0, z = vec.z or 0 }
  end
  return { x = vec.x / len, y = vec.y / len, z = vec.z or 0 }
end

function util.scale2D(vec, scale)
  return { x = vec.x * scale, y = vec.y * scale, z = vec.z or 0 }
end

function util.add2D(a, b)
  return { x = a.x + b.x, y = a.y + b.y, z = (a.z or 0) + (b.z or 0) }
end

function util.sub2D(a, b)
  return { x = a.x - b.x, y = a.y - b.y, z = (a.z or 0) - (b.z or 0) }
end

function util.midpoint2D(a, b)
  return { x = (a.x + b.x) * 0.5, y = (a.y + b.y) * 0.5, z = ((a.z or 0) + (b.z or 0)) * 0.5 }
end

function util.dot2D(a, b)
  return a.x * b.x + a.y * b.y
end

function util.copy(tbl)
  local result = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      result[k] = util.copy(v)
    else
      result[k] = v
    end
  end
  return result
end

return util
