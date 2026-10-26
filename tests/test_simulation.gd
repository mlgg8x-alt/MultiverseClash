extends "res://tests/test_case.gd"

const Simulation = preload("res://core/simulation.gd")
const SaveSystem = preload("res://core/save_system.gd")
const Q = preload("res://economy/stock_queries.gd")

const DAY := 200


func test_same_seed_same_outcome() -> void:
	var a = Simulation.new_game(99, true)
	var b = Simulation.new_game(99, true)
	Simulation.run(a, 6 * DAY)
	Simulation.run(b, 6 * DAY)
	check_eq(Simulation.state_hash(a), Simulation.state_hash(b), "identical runs hash identically")


func test_goods_conserved_every_tick() -> void:
	var s = Simulation.new_game(3, true)
	for i in 10 * DAY:
		Simulation.step(s)
		var errors: Array = s.ledger.conservation_errors()
		if not errors.is_empty():
			check(false, "tick %d: %s" % [s.tick, errors])
			return
	check(s.ledger.produced.get("food", 0) > 0, "economy actually produced goods")
	check(s.ledger.consumed.get("food", 0) > 0, "and consumed them")


func test_reload_reproduces_economy() -> void:
	var continuous = Simulation.new_game(17, true)
	Simulation.run(continuous, 4 * DAY + 37)
	var text := SaveSystem.to_json(continuous)
	var reloaded = SaveSystem.from_json(text)
	check_eq(Simulation.state_hash(reloaded), Simulation.state_hash(continuous), "reload matches saved state")
	Simulation.run(continuous, 4 * DAY)
	Simulation.run(reloaded, 4 * DAY)
	check_eq(Simulation.state_hash(reloaded), Simulation.state_hash(continuous), "reloaded run stays in lockstep")


func test_save_file_round_trip() -> void:
	var s = Simulation.new_game(8)
	Simulation.run(s, DAY)
	var path := "user://test_save.json"
	check_eq(SaveSystem.save_to_file(s, path), OK, "save written")
	var back = SaveSystem.load_from_file(path)
	check(back != null, "save loaded")
	if back != null:
		check_eq(Simulation.state_hash(back), Simulation.state_hash(s), "file round trip is exact")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_rejects_future_save_version() -> void:
	var data: Dictionary = Simulation.new_game(1).serialize()
	data["save_version"] = 999
	check(SaveSystem.from_json(JSON.stringify(data)) == null, "newer save versions are refused")


func test_ai_sustains_settlements() -> void:
	for seed_value in [1, 2, 3]:
		var s = Simulation.new_game(seed_value, true)
		Simulation.run(s, 20 * DAY)
		for f in s.factions:
			var pop: int = s.faction_agents(f.id).size()
			var built := 0
			for b in s.faction_buildings(f.id):
				if b.built:
					built += 1
			var label := "seed %d %s" % [seed_value, f.name]
			check(pop >= Simulation.START_CITIZENS, "%s keeps its population (%d)" % [label, pop])
			check(built >= 1 + Simulation.START_HOUSES + 4, "%s expanded (%d buildings)" % [label, built])
			check(Q.food_total(s, f.id) > 0, "%s has food in stock" % label)
		check(s.ledger.conservation_errors().is_empty(), "seed %d ledger balanced" % seed_value)


func test_performance_metrics() -> void:
	var s = Simulation.new_game(11, true)
	Simulation.run(s, 10 * DAY)   # grow the settlements first
	var ticks := 2 * DAY
	var start := Time.get_ticks_usec()
	Simulation.run(s, ticks)
	var secs := (Time.get_ticks_usec() - start) / 1000000.0
	print("    perf: %d agents, %d buildings, %.0f ticks/s, %.2f ms/tick" % [
		s.agents.size(), s.buildings.size(), ticks / secs, secs * 1000.0 / ticks])
	check(ticks / secs > 60.0, "simulation keeps up with 60 ticks/s")
