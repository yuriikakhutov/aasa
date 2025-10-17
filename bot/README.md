# UCZone Autonomous Hero Bot

This project provides a fully featured Lua bot for the UCZone/USZone platform. It adheres to the official SDK callbacks and integrates a modular AI stack covering perception, decision-making, action scheduling, pathing, and combat micro.

## Project Layout

```
/bot/
  config.json                # Behaviour configuration
  main.lua                   # Entry point returning UCZone callbacks
  /core/                     # Core AI subsystems
  /ai/                       # Behaviour and tactics helpers
  /integration/              # SDK integration glue
  /tests/                    # Offline Lua tests
  /logs/                     # Log output directory (kept for compatibility)
```

Each module is documented inline and follows a Perception → Blackboard → Decision → Scheduler → Action pipeline.

## Getting Started

1. Copy the `bot` directory and top-level `Script.lua` into your UCZone scripts folder.
2. Launch UCZone in unsafe mode so callbacks such as `OnEntityHurt` are triggered.
3. Ensure the SDK can locate Lua dependencies using the default `package.path`. The entry point already extends it for the `/bot` hierarchy.
4. Load the script in the UCZone menu. On successful load the console prints `UCZone AI bot initialized`.

## Configuration

Runtime behaviour is controlled through `bot/config.json`:

| Key | Description |
| --- | ----------- |
| `debug` | Enables verbose logging when `true`. |
| `logLevel` | Minimum log level (`ERROR`, `WARN`, `INFO`, `DEBUG`). |
| `aggression` | Base aggression coefficient for the selector. |
| `farmRadius` | Maximum distance for creep farming decisions. |
| `roamRadius` | Search radius for roaming/ally awareness. |
| `retreatHpThreshold` | HP ratio that triggers defensive logic. |
| `retreatManaThreshold` | Mana ratio threshold for safe checks. |
| `fightWinChance` | Required utility score to force a fight. |
| `healHpThreshold` | HP ratio prompting self-healing. |
| `maxQueuedActions` | Scheduler queue length to avoid command spam. |
| `logRateLimit` | Minimum seconds between `INFO` logs. |
| `maxLogEntries` | History buffer depth. |
| `dangerRadius` | Radius for threat evaluations. |
| `kiteRange` | Distance to keep while kiting enemies. |
| `maxChaseDistance` | Maximum pursuit range before abandoning. |
| `fallbackSafeTime` | Seconds to keep retreat flag active. |

Edit the JSON and reload the script in-game to apply changes.

## Behaviour Overview

- **Perception:** Polls hero, allies, enemies, creeps, neutrals, and structures. Tracks cooldowns, threat, and win probability.
- **Blackboard:** Central memory storing entity handles, timers, and derived metrics (HP/MP ratios, target cache).
- **Decision Selector:** Utility-based scoring for modes `retreat`, `fight`, `roam`, `farm`, `heal`, `push`, and `defend`.
- **Scheduler:** Deduplicates action requests and executes them with throttling to prevent command spam.
- **Movement & Navigation:** Fountain fallback, kiting, and waypoint roaming integrated with GridNav.
- **Combat:** Prioritises disables, nukes, and attack-move sequences with kill-secure awareness.
- **Items & Skills:** Handles heals, escapes, and burst combos with cooldown/mana checks.

## Running Tests

Offline sanity checks can be executed with any Lua 5.3+ runtime:

```
lua bot/tests/test_selector.lua
lua bot/tests/test_threat.lua
lua bot/tests/test_scheduler.lua
```

These tests stub the UCZone environment and verify selector logic, threat scoring, and scheduler throttling.

## FAQ

**The bot spams commands or jitters.** Increase `logRateLimit` or `maxQueuedActions` and ensure the game runs at ≥60 FPS.

**The bot retreats too frequently.** Raise `retreatHpThreshold` and/or lower `dangerRadius`.

**How do I increase aggression?** Increase `aggression` and lower `fightWinChance` to bias the selector toward skirmishes.

**Where are logs stored?** Logs are printed to the console; the `/bot/logs` directory remains for compatibility if file logging is added later.
