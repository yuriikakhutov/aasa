local api = require("bot.integration.uc_api")

local items = {}

local function use_item(bb, itemName, target)
  local hero = bb.state.self
  local player = bb.state.player or api.get_local_player()
  if not hero or not player or not NPC or not NPC.GetItemByName then
    return false
  end
  local item = NPC.GetItemByName(hero, itemName, true)
  if not item or not api.can_cast_ability(hero, item) then
    return false
  end
  if target then
    return api.cast_ability_on_target(player, item, target)
  end
  return api.cast_ability_on_position(player, item, api.get_position(hero))
end

function items.try_healing(bb)
  if use_item(bb, "item_flask") then
    return true
  end
  if use_item(bb, "item_greater_famango") then
    return true
  end
  return false
end

return items
