# UCZone Bot

Autonomous combat bot for USZone/UCZone built with the official Lua SDK. The bot implements a modular decision pipeline **Perception → Blackboard/Memory → Selector → Scheduler → Action Scheduler → Skills/Items → Movement/Pathing → Combat/Evade** and ships with coordinated farming, rotations, economy and objective logic.

## Project layout

```
bot/
  config.json            -- runtime tuning parameters
  main.lua               -- UCZone callback entry point
  core/                  -- reusable subsystems (perception, memory, nav, combat, economy)
  ai/                    -- high level behaviours and micro tactics
  integration/           -- thin wrappers over UCZone APIs and filesystem helpers
  tests/                 -- Lua unit tests for deterministic logic
  logs/                  -- log directory (kept for UCZone logging compatibility)
```

## Installation

1. Copy the entire `bot` directory into your UCZone scripts directory (`game/dota_addons/uczone/scripts/vscripts`).
2. Enable the script from the UCZone menu and reload scripts or restart the match.
3. Ensure the UCZone client runs in **unsafe** mode if you need damage callbacks (`Callbacks.OnEntityHurt`).

## Configuration

Edit `config.json` to tune behaviour without touching Lua code:

- Core risk tuning: `aggression`, `retreatHpThreshold`, `healHpThreshold`, `fightEngageThreshold`.
- Spatial radii: `farmSearchRadius`, `roamSearchRadius`, `pushWaveRange`, `nav.safeWaypointRadius`.
- Combat/micro: `pursueTimeout`, `orbwalkHold`, `orbwalkMoveStep`.
- Macro timings: `runePrepTime`, `runeInterval`, `pullPrepWindow`, `stackPrepWindow`, `rotationCooldown`.
- Safety scoring: `dangerDecay`, `farmSafetyBias`, `farmHeatmapDecay`, `tpDefendThreshold`.
- Economy toggles: `economy.forceTp`, `economy.allowGreed`, `economy.farmAccelerators`, `shopMinGold`.
- Logging: `logLevel`, `logLimitPerTick`, `debug`.

The file is loaded on script boot; restart scripts to apply changes.

## Behaviour overview

- **Perception** gathers hero, ally, enemy and creep state each tick, tracks danger heatmaps, stack/pull windows, and derives counter-building hints.
- **Blackboard** aggregates metrics such as threat, wave advantage, rune/rotation timers, buy queues, lane assignments and heatmaps.
- **Selector** evaluates utilities for `retreat`, `heal`, `fight`, `gank`, `farm`, `stack`, `pull`, `rune`, `push`, `defend`, `shop`, `objective`, always falling back to `roam`.
- **Scheduler** throttles action dispatch so the bot issues at most one high-level command per ~0.12s.
- **Actions** trigger specialised routines (farm routes, rune control, gank execution, objective pressure) via `core/movement`, `core/combat`, `core/objective`, and call UCZone orders (`NPC.MoveTo`, `Player.AttackTarget`, `Ability.Cast*`).
- **Economy** plans lane-appropriate builds, reacts to enemy comps (BKB vs heavy magic, Vessel vs healers, cleave vs illusions), keeps TP scrolls stocked, and auto-learns skills.
- **Navigation** exposes curated waypoints for lanes, rune spots, pull boxes, juke routes and safe retreats on top of UCZone path queries.

## Running tests

Inside UCZone's Lua console or any Lua 5.3+ interpreter with this directory on the package path:

```lua
local run = require("tests.init")
print(require("inspect")(run()))
```

Each test returns `{ success = true }` on pass; failures carry an error message.

## FAQ

**The bot spams commands.**  Increase `scheduler.cooldown` in `core/scheduler.lua` or lower `aggression` in `config.json`.

**The bot overcommits into bad fights.**  Raise `fightEngageThreshold` or reduce `aggression`; the selector will prioritise `retreat`/`defend` earlier.

**The bot ignores runes/stacks.**  Ensure `runePrepTime`, `stackPrepWindow`, and `pullPrepWindow` are not set to zero and that game time callbacks are firing.

**No logs appear.**  Set `debug` to `true` and ensure UCZone logging is enabled.

**Performance considerations.**  Perception avoids allocations on hot paths, caches lookup tables, and command emission is throttled to stay within the 2–5 ms tick budget.

## Logging

Logs are routed through UCZone's `Log.Write` with level filtering (`INFO`, `WARN`, `ERROR`, optional `DEBUG`). The logger enforces `logLimitPerTick` to prevent flooding.

## Extending

- Add new behaviours in `ai/behaviors.lua` and hook them in `core/selector.lua`.
- Implement specialist tactics in `ai/tactics.lua` and reuse them from actions.
- Expand map intelligence or add more API shims via `core/nav.lua` and `integration/uc_api.lua`.
- Enhance economy logic in `core/economy.lua` to support hero-specific builds.

## Safety

The bot automatically retreats when projected incoming damage spikes, kites melee opponents via orb-walking, and uses self-heal items when below configured HP/MP ratios. When low resources are detected it falls back towards the allied triangle/fountain using curated safe waypoints and GridNav pathing.
