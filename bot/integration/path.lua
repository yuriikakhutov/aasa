local M = {}

local CANDIDATES = {
    "./scripts/bot/",
    ".\\scripts\\bot\\",
    "scripts/bot/",
    "bot/",
    "./bot/",
    "",
}

local function normalize(path)
    return path:gsub("\\", "/")
end

local detected

local function probe(base)
    if base == "" then
        return true
    end
    local testPath = base .. "main.lua"
    local handle = io.open(testPath, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

local function choose_base()
    if detected then
        return detected
    end
    for _, base in ipairs(CANDIDATES) do
        if probe(base) then
            detected = base
            return detected
        end
    end
    detected = CANDIDATES[1]
    return detected
end

function M.root()
    return choose_base()
end

function M.join(...)
    local base = {}
    local args = { ... }
    for i = 1, #args do
        local chunk = tostring(args[i])
        if chunk ~= "" then
            chunk = normalize(chunk)
            if chunk:sub(-1) == "/" then
                chunk = chunk:sub(1, -2)
            end
            table.insert(base, chunk)
        end
    end
    return table.concat(base, "/")
end

function M.exists(path)
    local handle = io.open(path, "r")
    if handle then
        handle:close()
        return true
    end
    return false
end

return M
