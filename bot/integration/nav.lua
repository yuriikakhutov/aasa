local api = require("bot.integration.uc_api")
local util = require("bot.core.util")

local nav = {}

local cachedFountain = {}

function nav.get_fountain_position(team)
  if cachedFountain[team] then
    return cachedFountain[team]
  end
  local position
  if team == Enum.TeamType.TEAM_FRIENDLY then
    position = Vector(-7200, -6666, 512)
  elseif team == Enum.TeamType.TEAM_ENEMY then
    position = Vector(7130, 6544, 512)
  else
    position = Vector(0, 0, 0)
  end
  cachedFountain[team] = { x = position.x, y = position.y, z = position.z }
  return cachedFountain[team]
end

function nav.is_position_safe(pos)
  if not pos then
    return false
  end
  return not api.in_danger_zone(pos)
end

function nav.ensure_pathable(pos)
  if nav.is_position_safe(pos) then
    return pos
  end
  return { x = pos.x + 120, y = pos.y + 120, z = pos.z or 0 }
end

function nav.next_roam_point(hero)
  local origin = api.get_position(hero)
  local offsets = {
    { 1200, 0 },
    { -1200, 0 },
    { 0, 1200 },
    { 0, -1200 },
  }
  local best
  for i = 1, #offsets do
    local x, y = offsets[i][1], offsets[i][2]
    local candidate = { x = origin.x + x, y = origin.y + y, z = origin.z }
    if nav.is_position_safe(candidate) then
      best = candidate
      break
    end
  end
  return best or origin
end

return nav
