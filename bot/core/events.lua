local events = {}

local listeners = {}

function events.emit(name, payload)
  local handlers = listeners[name]
  if not handlers then
    return
  end
  for i = 1, #handlers do
    handlers[i](payload)
  end
end

function events.on(name, handler)
  if not listeners[name] then
    listeners[name] = {}
  end
  table.insert(listeners[name], handler)
end

return events
