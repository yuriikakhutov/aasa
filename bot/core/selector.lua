local selector = {}

local function utility_scores(bb, cfg)
  local scores = {}
  local hpRatio = bb:hpRatio()
  local manaRatio = bb:manaRatio()
  local threat = bb.state.threat or 0
  local winChance = bb.state.winChance or 0.5
  local safe = bb.state.safe
  local healReady = bb.state.healReady

  scores.retreat = math.max(threat, (cfg.retreatHpThreshold - hpRatio) * 4)
  if bb:isRetreating(cfg._now or 0) then
    scores.retreat = scores.retreat + 1.5
  end

  scores.heal = healReady and (1 - hpRatio) * 0.8 or 0
  scores.fight = (winChance - cfg.fightWinChance) * 1.2 + (bb.state.aggression or 0.5)
  scores.fight = math.max(scores.fight, 0)
  scores.roam = safe and bb.state.needGold and 0.6 or 0.3
  scores.farm = safe and (1 - scores.fight) * 0.5 + (1 - threat) * 0.3
  scores.push = safe and bb.state.waveAdvantage and 0.5 or 0
  scores.defend = not safe and 0.4 or 0

  return scores
end

function selector.decide(bb, cfg, now)
  cfg._now = now
  local scores = utility_scores(bb, cfg)
  local ranked = {}
  for mode, score in pairs(scores) do
    table.insert(ranked, { mode = mode, score = score })
  end
  table.sort(ranked, function(a, b)
    return a.score > b.score
  end)
  if ranked[1] and ranked[1].score > 0 then
    return ranked[1].mode
  end
  return "farm"
end

return selector
