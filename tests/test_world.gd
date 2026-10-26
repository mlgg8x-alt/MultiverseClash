extends "res://tests/test_case.gd"

const MapGenerator = preload("res://world/map_generator.gd")
const Pathfinder = preload("res://world/pathfinder.gd")
const Simulation = preload("res://core/simulation.gd")


func test_generation_is_deterministic() -> void:
	var a = MapGenerator.generate(42, 64, 48, Simulation.START_SITES)
	var b = MapGenerator.generate(42, 64, 48, Simulation.START_SITES)
	var c = MapGenerator.generate(43, 64, 48, Simulation.START_SITES)
	check(a.tiles == b.tiles, "same seed gives same map")
	check(a.tiles != c.tiles, "different seed gives different map")


func test_start_sites_are_viable_across_seeds() -> void:
	for seed_value in range(1, 31):
		var m = MapGenerator.generate(seed_value, 64, 48, Simulation.START_SITES)
		for site in Simulation.START_SITES:
			var problems := MapGenerator.validate_site(m, site)
			check(problems.is_empty(), "seed %d: %s" % [seed_value, problems])


func test_path_avoids_water() -> void:
	var m = MapGenerator.generate(7, 64, 48, Simulation.START_SITES)
	var site: Vector2i = Simulation.START_SITES[0]
	var goal := site + Vector2i(2, 2)
	var path := Pathfinder.find_path(m, site, goal)
	check(not path.is_empty() and path[-1] == goal, "path reaches goal")
	for p in path:
		check(m.is_passable(p), "path step %s is passable" % p)
