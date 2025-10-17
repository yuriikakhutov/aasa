local api = require("bot.integration.uc_api")
local events = require("bot.core.events")

local hooks = {}

function hooks.init(dispatch)
  local callbacks = {}

  callbacks.OnScriptsLoaded = function()
    dispatch({ type = "scripts_loaded" })
  end

  callbacks.OnUpdate = function()
    dispatch({ type = "tick", dt = api.get_frame_time(), time = api.get_time() })
  end

  callbacks.OnEntityCreate = function(entity)
    dispatch({ type = "entity_create", entity = entity })
  end

  callbacks.OnEntityDestroy = function(entity)
    dispatch({ type = "entity_destroy", entity = entity })
  end

  callbacks.OnEntityHurt = function(data)
    dispatch({ type = "damage_taken", amount = data.damage, source = data.source })
  end

  callbacks.OnEntityKilled = function(data)
    dispatch({ type = "entity_killed", target = data.target, source = data.source })
  end

  callbacks.OnPrepareUnitOrders = function(order)
    events.emit("prepare_order", order)
    return true
  end

  return callbacks
end

return hooks
