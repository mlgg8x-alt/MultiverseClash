# INDUSTRIAL MULTIVERSE — GAME REFERENCE
Version: 0.2 | Status: First vertical slice in progress | Updated: 2026-10-26

## Vision
A real-time Godot civilization and industrial automation simulation combining Songs of Syx-style population/city management with Factorio-style production and logistics. Existing crossover civilizations and player-created factions inhabit separate continents with recognizable canonical homelands. All factions participate in the same persistent economy, diplomacy, and warfare simulation.

## Confirmed design decisions
- Engine: Godot 4.3 (pinned for the vertical slice; revisit before production).
- World: separate continents, canonical homelands, procedurally generated frontiers and connections.
- Playable: established fictional factions and custom civilizations.
- Initial universes: Attack on Titan, Naruto, Fullmetal Alchemist, Youjo Senki.
- Gameplay pillars: citizens, physical resources, production, automation, expansion, competing AI, warfare.
- Scale ambition: large cities and continental competition; quantitative targets remain undecided.

## World generation
1. Load authored homeland masks and landmark anchors for each universe.
2. Generate global continental arrangement and ocean gaps without distorting landmark relationships.
3. Generate terrain, rivers, climate, soil and mineral distributions subject to authored constraints.
4. Subdivide into regions and provinces; initialize settlement sites and transport links.
5. Seed canonical settlements, populations, military assets, stocks and industry based on chosen start era.
6. Generate procedural frontiers; validate accessibility and resource viability; save seed and generation version.

## Simulation levels
- Global: diplomacy, trade, nation-level priorities, strategic military movements.
- Region: settlement economies, infrastructure, transport flows, labor pools, army supply.
- Local: visible workers, construction, production buildings, item transport, tactical fighting.
- Invariants: inventory conserved across detail transitions; one authoritative ownership and stock ledger; no double simulation.

## Economy
Shared resources: food, timber, stone, ores, coal, fuel, steel, machinery, construction goods, ammunition, consumer goods. Faction-specific processes add specialist capabilities without free unlimited material generation. Every recipe declares input amounts, output amounts, processing time, labor skill and staffing, power, maintenance, and waste/byproducts.

### Faction sketches (subject to canon/start-era review)
- Attack on Titan: fortification, ODM equipment, conventional industrialization, specialized Titan mechanics.
- Naruto: shinobi training, chakra-skilled work, clans, techniques, specialist bottlenecks.
- Fullmetal Alchemist: transmutation-based construction and manufacturing under material constraints.
- Youjo Senki: mass manufacturing, rail supply, aviation, artillery, specialist mages.
- Custom: configurable starting culture, geography, industry and government; no unrestricted cross-faction tech access.

## Population
Represent households, jobs, housing, food, health, education, migration and satisfaction. Simulate individuals selectively in nearby maps; aggregate distant cohorts. Staffing and skill influence production; goods and services influence migration and unrest.

## Logistics
Start with porters/carts/roads; progress to warehouses, conveyor belts, powered handling, trains and automated distribution where faction technology permits. Represent network throughput, capacity, transit time, congestion, storage and delivery priorities. Switch distant networks to aggregate flows with conservation checks.

## AI expansion
Strategic planner selects goals (food security, industrial capacity, defense, expansion, diplomacy). Regional planner selects projects and resource budgets. Local planner schedules buildings, workforce and logistics. AI uses same recipes, stocks, construction costs and army supply rules as player. Add bounded planning cadence and reproducible decisions.

## Warfare
Armies are recruited, trained, equipped and supplied through the economy. Strategic layer resolves movement, front lines, supply and distant battles; local layer renders nearby tactical encounters. Unit types include conventional troops and universe-specific specialists. Preserve asymmetry; constrain specialists via availability, training, fatigue, material costs and vulnerabilities. Casualties and destruction affect the civilian economy.

## Godot architecture
Suggested modules:
- core/ : simulation clock, event bus, save versioning, seeded RNG
- world/ : generation, chunks, regions, terrain, ownership
- economy/ : resource registry, recipes, inventory, industry, energy
- population/ : cohorts, households, employment, needs
- logistics/ : transport graphs, flow solver, deliveries
- factions/ : definitions, tech trees, diplomacy, abilities
- ai/ : strategic, regional, local planning
- military/ : formations, supply, combat resolution
- presentation/ : map rendering, LOD, UI, selection, overlays
- tests/ : deterministic replay, inventory conservation, performance

Central simulation clock with fixed ticks. Pure data state independent from Nodes. GDScript initially; optimize hot paths only after profiling. Chunked rendering and map streaming. Versioned save files.

## First vertical slice
1. Generate a small local map with forests, fertile soil and ore.
2. Place houses, farm, mine, warehouse and workshop.
3. Spawn workforce cohorts and visible representative agents.
4. Implement jobs, hauling, storage and production recipes.
5. Implement food consumption, staffing shortages and construction.
6. Add an AI settlement using the same rules.
7. Save/load, deterministic tests and performance metrics.
Acceptance: no resources created or lost through transport; shortages visibly halt production; AI can sustain a settlement without scripted free resources; reload reproduces the economy.

### Vertical slice status (v0.2)
Implemented: steps 1-5 and 7, plus a rule-based AI settlement (step 6) on the same rules.
All acceptance criteria are covered by headless tests (`run_tests.sh`): per-tick ledger
conservation, shortage/unstaffed/full-output halts, AI settlements growing for 20 days with
no free resources, same-seed determinism, and save/reload lockstep. Measured performance
is about 0.3 ms per tick with ~30 agents. Tuned numbers: 200 ticks/day, 1 food per citizen
per day, farm 2 food per 70 work-units, haul load 5. See README for the known gaps.

## Open design questions
- Exact canonical timelines and crossover contact date.
- Player starts as ruler, founder, or governor; ability to switch factions.
- Planet scale, map tile size, city populations, time compression.
- Detailed belt simulation versus aggregate flow thresholds.
- Tactical battle interface and player control scope.
- Diplomacy depth and victory conditions.
- Original assets, naming, and intellectual-property distribution considerations.

## Change log
- v0.2: pinned Godot 4.3; implemented the first vertical slice (local map, ledger, recipes, hauling, population, AI settlement, saves, tests).
- v0.1: established project vision, worlds, factions, simulation layers, economy, AI, warfare and prototype scope.
