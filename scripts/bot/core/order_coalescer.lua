---
-- Centralises order dispatch with anti-spam guarantees and shared history.
---

local Logger = require("scripts.bot.core.logger")

local OrderCoalescer = {}
OrderCoalescer.__index = OrderCoalescer

local DEFAULT_INTERVALS = {
    move = 0.14,
    attack = 0.14,
    cast = 0.14,
    item = 0.14,
}

local function now()
    return os.clock()
end

function OrderCoalescer.new(options)
    local cooldowns = {}
    for k, v in pairs(DEFAULT_INTERVALS) do
        cooldowns[k] = (options and options[k]) or v
    end
    return setmetatable({
        cooldowns = cooldowns,
        history = {},
        lastIssued = {
            move = { time = -math.huge, signature = nil },
            attack = { time = -math.huge, signature = nil },
            cast = { time = -math.huge, signature = nil },
            item = { time = -math.huge, signature = nil },
        },
        pending = {},
    }, OrderCoalescer)
end

function OrderCoalescer:canIssue(kind, signature)
    local record = self.lastIssued[kind]
    if not record then
        return false
    end
    local interval = self.cooldowns[kind] or 0.14
    local current = now()
    if current - record.time < interval then
        return false
    end
    if record.signature == signature and current - record.time < 0.6 then
        return false
    end
    return true
end

local unpack = table.unpack or unpack

local function makeAction(fn, ...)
    local args = { ... }
    return function()
        return fn(unpack(args))
    end
end

function OrderCoalescer:queue(kind, signature, fn, ...)
    if not fn then
        return false
    end
    if not self:canIssue(kind, signature) then
        return false
    end
    table.insert(self.pending, {
        kind = kind,
        signature = signature,
        action = makeAction(fn, ...),
    })
    return true
end

function OrderCoalescer:flush()
    if #self.pending == 0 then
        return {}
    end
    local issued = {}
    for _, entry in ipairs(self.pending) do
        local ok, result = pcall(entry.action)
        if ok and result then
            local stamp = now()
            self.lastIssued[entry.kind] = { time = stamp, signature = entry.signature }
            table.insert(self.history, {
                time = stamp,
                kind = entry.kind,
                signature = entry.signature,
            })
            table.insert(issued, entry)
        else
            Logger.warn("Order %s failed: %s", tostring(entry.kind), tostring(result))
        end
    end
    self.pending = {}
    return issued
end

function OrderCoalescer:getHistory()
    return self.history
end

function OrderCoalescer:resetPending()
    self.pending = {}
end

return OrderCoalescer

