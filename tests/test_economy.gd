extends "res://tests/test_case.gd"

const Simulation = preload("res://core/simulation.gd")
const Building = preload("res://economy/building.gd")
const Agent = preload("res://population/agent.gd")
const ProductionSystem = preload("res://economy/production_system.gd")
const ConstructionSystem = preload("res://economy/construction_system.gd")


## A bare state with no settlements, so each test controls exactly what exists.
func _empty_state():
	var s = Simulation.new_game(5)
	s.buildings.clear()
	s.agents.clear()
	s.ledger = load("res://economy/ledger.gd").new()
	return s


func _building(s, type: String, pos: Vector2i, built := true):
	var b := Building.new(s.new_id(), 0, type, pos)
	b.built = built
	s.add_building(b)
	return b


func _worker_at(s, b, task_type := "work"):
	var a := Agent.new(s.new_id(), 0, b.pos)
	a.role = "builder" if task_type == "build" else "worker"
	a.assignment = b.id
	a.task = {"type": task_type, "building": b.id}
	s.add_agent(a)
	return a


func test_missing_input_halts_production() -> void:
	var s = _empty_state()
	var shop = _building(s, "workshop", Vector2i(10, 10))
	_worker_at(s, shop)
	for i in 100:
		ProductionSystem.update(s)
	check_eq(shop.status, ProductionSystem.STATUS_MISSING_INPUT, "workshop reports missing input")
	check_eq(s.ledger.produced.get("tools", 0), 0, "nothing produced without inputs")
	s.ledger.seed_initial(shop.id, "iron_ore", 2)
	s.ledger.seed_initial(shop.id, "timber", 1)
	for i in 60:
		ProductionSystem.update(s)
	check_eq(s.ledger.amount(shop.id, "tools"), 1, "one cycle completes once inputs arrive")
	check_eq(s.ledger.amount(shop.id, "iron_ore"), 0, "inputs consumed")
	check(s.ledger.conservation_errors().is_empty(), "ledger balanced")


func test_unstaffed_building_does_not_produce() -> void:
	var s = _empty_state()
	var farm = _building(s, "farm", Vector2i(10, 10))
	for i in 200:
		ProductionSystem.update(s)
	check_eq(farm.status, ProductionSystem.STATUS_NO_WORKERS, "farm reports no workers")
	check_eq(s.ledger.total_held(farm.id), 0, "nothing produced")


func test_hunger_halves_output() -> void:
	var s = _empty_state()
	var fed_farm = _building(s, "farm", Vector2i(10, 10))
	var hungry_farm = _building(s, "farm", Vector2i(12, 10))
	_worker_at(s, fed_farm)
	_worker_at(s, hungry_farm).hunger_days = 1
	for i in 140:
		ProductionSystem.update(s)
	check_eq(s.ledger.amount(fed_farm.id, "food"), 4, "fed worker completes two cycles")
	check_eq(s.ledger.amount(hungry_farm.id, "food"), 2, "hungry worker completes one")


func test_full_output_halts_production() -> void:
	var s = _empty_state()
	var farm = _building(s, "farm", Vector2i(10, 10))
	_worker_at(s, farm)
	s.ledger.seed_initial(farm.id, "food", 12)
	for i in 100:
		ProductionSystem.update(s)
	check_eq(farm.status, ProductionSystem.STATUS_OUTPUT_FULL, "farm reports full output")
	check_eq(s.ledger.amount(farm.id, "food"), 12, "no overproduction")


func test_construction_needs_materials_and_builders() -> void:
	var s = _empty_state()
	var site = _building(s, "house", Vector2i(10, 10), false)
	ConstructionSystem.update(s)
	check_eq(site.status, ConstructionSystem.STATUS_AWAITING_MATERIALS, "site waits for materials")
	s.ledger.seed_initial(site.id, "timber", 4)
	s.ledger.seed_initial(site.id, "stone", 1)
	ConstructionSystem.update(s)
	check_eq(site.status, ConstructionSystem.STATUS_NO_BUILDERS, "site waits for builders")
	_worker_at(s, site, "build")
	for i in 40:
		ConstructionSystem.update(s)
	check(site.built, "house completed after its build work")
	check_eq(s.ledger.total_held(site.id), 0, "materials consumed into the structure")
	check(s.ledger.conservation_errors().is_empty(), "ledger balanced")
