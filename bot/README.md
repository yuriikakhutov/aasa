# UCZone Bot

Autonomous combat bot for USZone/UCZone built with the official Lua SDK. The bot implements a modular decision pipeline **Perception → Blackboard → Selector → Scheduler → Actions → Movement/Combat** and is ready to be dropped into the UCZone script folder.

## Project layout

```
bot/
  config.json            -- runtime tuning parameters
  main.lua               -- UCZone callback entry point
  core/                  -- reusable subsystems (perception, memory, scheduler, etc.)
  ai/                    -- high level behaviours and micro tactics
  integration/           -- thin wrappers over UCZone APIs
  tests/                 -- Lua unit tests for deterministic logic
  logs/                  -- log directory (kept for UCZone logging compatibility)
```

## Installation

1. Copy the entire `bot` directory into your UCZone scripts directory (`game/dota_addons/uczone/scripts/vscripts`).
2. Enable the script from the UCZone menu and reload scripts or restart the match.
3. Ensure the UCZone client runs in **unsafe** mode if you need damage callbacks (`Callbacks.OnEntityHurt`).

## Configuration

Edit `config.json` to tune risk appetite and radii without touching Lua code:

- `aggression` – base aggression multiplier for selector.
- `retreatHpThreshold` / `healHpThreshold` – health ratio cut-offs for retreating/healing.
- `farmSearchRadius`, `roamSearchRadius`, `pushWaveRange` – distances used by perception.
- `fightEngageThreshold` – minimum win probability before forcing a fight.
- `logLevel`, `logLimitPerTick`, `debug` – logging verbosity.

Configuration is loaded at runtime; restart scripts to apply changes.

## Behaviour overview

- **Perception** gathers hero, ally, enemy and creep state each tick using `Heroes`, `NPCs`, `Entity`, `GridNav` and stores it on the blackboard.
- **Blackboard** aggregates derived metrics (threat, wave advantage, heal readiness, kill windows).
- **Selector** scores `retreat`, `heal`, `fight`, `farm`, `push`, `roam` utilities and picks the highest option every update.
- **Scheduler** throttles action dispatch so the bot issues at most one high-level command per 0.12s.
- **Actions** trigger micro routines via `core/combat`, `core/movement`, `core/skills`, `core/items` and send UCZone orders (`NPC.MoveTo`, `Player.PrepareUnitOrders`, `Ability.Cast*`).

## Running tests

Inside UCZone's Lua console or any Lua 5.3+ interpreter with this directory on the package path:

```lua
local run = require("tests.init")
print(require("inspect")(run()))
```

Each test returns `{ success = true }` on pass; failures carry an error message.

## FAQ

**The bot spams commands.**  Increase `scheduler.cooldown` or lower `aggression` in `config.json`.

**The bot overcommits into bad fights.**  Raise `fightEngageThreshold` or lower `aggression`.

**No logs appear.**  Set `debug` to `true` and ensure UCZone logging is enabled.

**Performance considerations.**  Perception avoids allocations on hot paths and reuses cached data where possible. Command emission is throttled to stay within the 2–5 ms tick budget.

## Logging

Logs are routed through UCZone's `Log.Write` with level filtering (`INFO`, `WARN`, `ERROR`, optional `DEBUG`). The logger enforces `logLimitPerTick` to prevent flooding.

## Extending

- Add new behaviours in `ai/behaviors.lua` and hook them in `core/selector.lua`.
- Implement specialist tactics in `ai/tactics.lua` and reuse them from actions.
- Expose more SDK functions inside `integration/uc_api.lua` or `integration/nav.lua` as needed.

## Safety

The bot automatically retreats when threat exceeds the configured threshold, will kite melee opponents, and uses self-heal items when below configured HP/MP ratios. When low resources are detected, it falls back towards the allied fountain using `GridNav` safe positions.
