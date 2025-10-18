---
-- Lightweight profiler collecting tick durations and order counts.
---

local Logger = require("scripts.bot.core.logger")

local Profiler = {}
Profiler.__index = Profiler

function Profiler.new()
    return setmetatable({
        ticks = {},
        orders = { move = 0, attack = 0, cast = 0, item = 0 },
        lastFlush = os.clock(),
    }, Profiler)
end

function Profiler:recordTick(kind, duration)
    self.ticks[kind] = self.ticks[kind] or { count = 0, total = 0, max = 0 }
    local entry = self.ticks[kind]
    entry.count = entry.count + 1
    entry.total = entry.total + duration
    if duration > entry.max then
        entry.max = duration
    end
end

function Profiler:recordOrders(orderList)
    for _, order in ipairs(orderList or {}) do
        if self.orders[order.kind] then
            self.orders[order.kind] = self.orders[order.kind] + 1
        end
    end
end

function Profiler:flushIfNeeded()
    local now = os.clock()
    if now - self.lastFlush < 5 then
        return
    end
    self.lastFlush = now
    os.execute("mkdir -p reports")
    local file, err = io.open("reports/profile.csv", "w")
    if not file then
        Logger.warn("Profiler flush failed: %s", tostring(err))
        return
    end
    file:write("section,count,total,max\n")
    for kind, entry in pairs(self.ticks) do
        file:write(string.format("%s,%d,%.6f,%.6f\n", kind, entry.count, entry.total, entry.max))
    end
    file:write("orders,move,attack,cast,item\n")
    file:write(string.format("totals,%d,%d,%d,%d\n", self.orders.move, self.orders.attack, self.orders.cast, self.orders.item))
    file:close()
end

return Profiler

