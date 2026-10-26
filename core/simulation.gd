extends RefCounted
## Fixed-tick simulation driver. Systems run in a fixed order on pure data; nothing here
## touches scene Nodes, so the same code runs in the game, in tests and headless.

const SimState = preload("res://core/sim_state.gd")
const Defs = preload("res://economy/defs.gd")
const Building = preload("res://economy/building.gd")
const Agent = preload("res://population/agent.gd")
const Faction = preload("res://factions/faction.gd")
const MapGenerator = preload("res://world/map_generator.gd")
const Commands = preload("res://core/commands.gd")
const SettlementPlanner = preload("res://ai/settlement_planner.gd")
const LaborAllocator = preload("res://population/labor_allocator.gd")
const PopulationSystem = preload("res://population/population_system.gd")
const HaulPlanner = preload("res://logistics/haul_planner.gd")
const AgentSystem = preload("res://logistics/agent_system.gd")
const ProductionSystem = preload("res://economy/production_system.gd")
const ConstructionSystem = preload("res://economy/construction_system.gd")

const MAP_SIZE := Vector2i(64, 48)
const START_SITES: Array[Vector2i] = [Vector2i(14, 24), Vector2i(49, 24)]
const START_CITIZENS := 6
const START_HOUSES := 2
const START_STOCK := {"food": 40, "timber": 30, "stone": 8}
const LABOR_INTERVAL := 20
const HAUL_INTERVAL := 5


## Creates a new world. With `player_ai` the player's faction is driven by the AI planner too.
static func new_game(seed_value: int, player_ai := false) -> SimState:
	Defs.ensure_loaded()
	var s := SimState.new()
	s.seed_value = seed_value
	s.rng.set_seed(seed_value)
	s.map = MapGenerator.generate(seed_value, MAP_SIZE.x, MAP_SIZE.y, START_SITES)
	s.factions = [
		Faction.new(0, "Player Colony", player_ai, Color("#4fa3ff")),
		Faction.new(1, "Rival Settlement", true, Color("#ff6a4f")),
	]
	for f in s.factions:
		_seed_settlement(s, f, START_SITES[f.id])
	return s


static func _seed_settlement(s: SimState, f: Faction, site: Vector2i) -> void:
	var hall := Building.new(s.new_id(), f.id, "town_hall", site)
	hall.built = true
	s.add_building(hall)
	f.town_hall = hall.id
	for res in START_STOCK:
		s.ledger.seed_initial(hall.id, res, START_STOCK[res])
	var houses := []
	for i in START_HOUSES:
		var pos = SettlementPlanner.find_site(s, f.id, "house")
		var house := Building.new(s.new_id(), f.id, "house", pos)
		house.built = true
		s.add_building(house)
		houses.append(house)
	for i in START_CITIZENS:
		var a := Agent.new(s.new_id(), f.id, site)
		a.home = houses[i % houses.size()].id
		s.add_agent(a)


static func step(s: SimState) -> void:
	Commands.apply_all(s)
	s.tick += 1
	for f in s.factions:
		var offset: int = f.id * 7
		if f.is_ai and (s.tick + offset) % SettlementPlanner.PLAN_INTERVAL == 0:
			SettlementPlanner.plan(s, f.id)
		if (s.tick + offset) % LABOR_INTERVAL == 0:
			LaborAllocator.allocate(s, f.id)
		if (s.tick + offset) % HAUL_INTERVAL == 0:
			HaulPlanner.plan(s, f.id)
	AgentSystem.update(s)
	ProductionSystem.update(s)
	ConstructionSystem.update(s)
	if s.tick % SimState.TICKS_PER_DAY == 0:
		PopulationSystem.daily(s)


static func run(s: SimState, ticks: int) -> void:
	for i in ticks:
		step(s)


static func state_hash(s: SimState) -> String:
	return JSON.stringify(s.serialize()).sha256_text()
