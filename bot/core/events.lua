local util = require("core.util")

local M = {
    handlers = {},
}

local function get_list(name)
    if not M.handlers[name] then
        M.handlers[name] = {}
    end
    return M.handlers[name]
end

function M.on(name, handler)
    assert(type(handler) == "function", "event handler must be function")
    local list = get_list(name)
    table.insert(list, handler)
end

function M.clear(name)
    if name then
        M.handlers[name] = {}
    else
        M.handlers = {}
    end
end

function M.dispatch(evt)
    if not evt or not evt.type then
        return
    end
    local list = M.handlers[evt.type]
    if not list then
        return
    end
    for _, handler in ipairs(list) do
        util.safe_call(handler, evt)
    end
end

return M
