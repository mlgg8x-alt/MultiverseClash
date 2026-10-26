# Industrial Multiverse

A real-time Godot civilization and industrial automation simulation. Design reference:
[docs/GAME_REFERENCE.md](docs/GAME_REFERENCE.md).

This repository currently holds the **first vertical slice**: a small generated local map
with two settlements (the player's and an AI rival) that run on the same economic rules.

## Running

Requires Godot **4.3** (standard build, not .NET).

```sh
godot --path .                    # play
GODOT=godot ./run_tests.sh        # headless test suite
godot --headless --path . -s res://tools/report.gd -- <seed> <days>   # daily economy report
```

Controls: `1`-`7` pick a building, left-click to place a construction site, `Space` pause,
`+`/`-` speed, `A` toggle autopilot for your colony, `F5` save, `F9` load, `N` new world.
Hover a building to see its status and stock. Status dots: green working, yellow no
workers, red missing input, orange output full.

## Layout

| Module | Contents |
|---|---|
| `core/` | `SimState` (all authoritative data), fixed-tick `Simulation` driver, commands, seeded RNG, versioned saves |
| `world/` | Local map, procedural generation with start-site viability, BFS pathfinding |
| `economy/` | Data-driven defs, the stock `Ledger`, buildings, production and construction systems |
| `population/` | Agents, labor allocation, daily food/hunger/migration |
| `logistics/` | Haul planning and agent movement/task execution |
| `factions/` | Faction data |
| `ai/` | Settlement planner (issues the same commands a player does) |
| `presentation/` | Playable view and HUD; reads state, writes only commands |
| `data/` | `resources.json`, `recipes.json`, `buildings.json` |
| `tests/` | Headless tests: ledger, world, economy rules, determinism, save/load, AI, perf |
| `military/` | Reserved for later milestones |

## Simulation rules in this slice

- **Single ledger.** Every unit of every resource is held by exactly one owner: a building,
  a construction site or a carrying agent. Goods enter only via world seeding or recipe
  output, leave only via recipe input, food consumption or construction, and otherwise only
  move with `transfer`. `Ledger.conservation_errors()` checks
  `initial + produced - consumed == held` and runs on every tick in the tests.
- **Determinism.** Integer-only state, a xorshift RNG whose state is saved, fixed system
  order, and id-ordered iteration. Same seed gives the same game, and a reload stays in
  lockstep with an uninterrupted run (both verified by state hash).
- **Production.** A recipe cycle starts only with inputs on site, workers present and room
  for output. Inputs are consumed at the start and outputs produced at the end.
  Hungry workers work at half rate.
- **Hauling.** Haulers carry up to 5 units for construction sites, house food, recipe inputs
  and output clearing. In-flight amounts are reserved so nothing is double-booked.
- **Population.** Citizens eat 1 food a day from home, or else from the nearest stock.
  Three hungry days in a row and they leave. A newcomer arrives each day when housing and
  3 days of food per head are available.
- **AI.** Rule-based priorities (food, timber, housing, stone, storage, ore, tools), one
  project at a time. It must afford the cost from real stock and it places sites through
  the same validated commands as the player.

## Known gaps / next steps

- Tools have no consumer yet, so mature settlements reach their stock targets and the
  surplus labor idles as haulers. Next: consumer goods, tool wear, or military supply.
- Terrain resources never deplete, and nearby buildings share the same terrain tiles.
- Agents path around water but walk through each other and through buildings. Hauling is
  per-agent; there is no aggregate flow layer yet.
- No skills, power or maintenance yet (fields are declared in recipes but unused).
- Universe-specific factions, regions and the global layer are not started.
