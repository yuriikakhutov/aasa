local path = require("integration.path")

local M = {}

function M.resolve_path(filename)
    local root = path.root()
    local attempts = {
        path.join(root, filename),
        path.join(filename),
        filename,
    }
    for _, candidate in ipairs(attempts) do
        local normalized = candidate
        if path.exists(normalized) then
            return normalized
        end
    end
    return attempts[1]
end

return M
