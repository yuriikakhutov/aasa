local M = {}

local BASE_PATHS = {
    ".\\scripts\\bot\\",
    "./scripts/bot/",
    "scripts/bot/",
    "./bot/",
    "bot/",
    "",
}

function M.resolve_path(filename)
    for _, base in ipairs(BASE_PATHS) do
        local path = base .. filename
        local handle = io.open(path, "r")
        if handle then
            handle:close()
            return path
        end
    end
    return BASE_PATHS[1] .. filename
end

return M
