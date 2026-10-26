extends RefCounted
## Procedural local map generation with viability guarantees around settlement start sites.

const LocalMap = preload("res://world/local_map.gd")
const SeededRng = preload("res://core/seeded_rng.gd")

const T := LocalMap.Terrain
const VIABILITY_RADIUS := 10
## Minimum tile counts required within VIABILITY_RADIUS of each start site, and the offset at
## which a patch is stamped when the generated terrain falls short.
const REQUIREMENTS := [
	{"terrain": T.FERTILE, "min": 12, "offset": Vector2i(-4, 4)},
	{"terrain": T.FOREST, "min": 12, "offset": Vector2i(5, -4)},
	{"terrain": T.STONE, "min": 5, "offset": Vector2i(-5, -5)},
	{"terrain": T.ORE, "min": 4, "offset": Vector2i(6, 5)},
]


static func generate(seed_value: int, width: int, height: int, start_sites: Array) -> LocalMap:
	var map := LocalMap.new(width, height)
	for y in height:
		for x in width:
			var elev := _fbm(x, y, 12.0, seed_value + 101)
			var moist := _fbm(x, y, 9.0, seed_value + 202)
			var rock := _fbm(x, y, 7.0, seed_value + 303)
			var fert := _fbm(x, y, 6.0, seed_value + 404)
			var t: int = T.GRASS
			if elev < 0.32:
				t = T.WATER
			elif rock > 0.70:
				t = T.ORE if _fbm(x, y, 3.0, seed_value + 505) > 0.6 else T.STONE
			elif moist > 0.60:
				t = T.FOREST
			elif fert > 0.56:
				t = T.FERTILE
			map.set_tile(Vector2i(x, y), t)
	for site in start_sites:
		_ensure_viable(map, site)
	map.compute_regions()
	return map


## Returns problems found at a start site; empty means viable.
static func validate_site(map: LocalMap, site: Vector2i) -> Array:
	var problems := []
	if not map.is_passable(site):
		problems.append("start site %s is not land" % site)
		return problems
	for req in REQUIREMENTS:
		if _reachable_count(map, site, req["terrain"]) < req["min"]:
			problems.append("start site %s lacks terrain %d" % [site, req["terrain"]])
	return problems


static func _ensure_viable(map: LocalMap, site: Vector2i) -> void:
	_stamp(map, site, 3, T.GRASS)
	# Mirror patch offsets for sites on the east half so patches face inland.
	var flip := -1 if site.x > map.width / 2 else 1
	for req in REQUIREMENTS:
		map.compute_regions()
		if _reachable_count(map, site, req["terrain"]) >= req["min"]:
			continue
		var off: Vector2i = req["offset"]
		var center := site + Vector2i(off.x * flip, off.y)
		center = center.clamp(Vector2i(2, 2), Vector2i(map.width - 3, map.height - 3))
		_carve_line(map, site, center)
		_stamp(map, center, 2, req["terrain"])
	map.compute_regions()


static func _reachable_count(map: LocalMap, site: Vector2i, terrain: int) -> int:
	var region := map.region_of(site)
	var n := 0
	for y in range(site.y - VIABILITY_RADIUS, site.y + VIABILITY_RADIUS + 1):
		for x in range(site.x - VIABILITY_RADIUS, site.x + VIABILITY_RADIUS + 1):
			var p := Vector2i(x, y)
			if map.in_bounds(p) and map.get_tile(p) == terrain and map.region_of(p) == region:
				n += 1
	return n


static func _stamp(map: LocalMap, center: Vector2i, radius: int, terrain: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var p := Vector2i(x, y)
			if map.in_bounds(p) and (p - center).length_squared() <= radius * radius + 1:
				map.set_tile(p, terrain)


static func _carve_line(map: LocalMap, from: Vector2i, to: Vector2i) -> void:
	var p := from
	while p != to:
		if p.x != to.x:
			p.x += signi(to.x - p.x)
		else:
			p.y += signi(to.y - p.y)
		if map.get_tile(p) == T.WATER:
			map.set_tile(p, T.GRASS)


static func _fbm(x: int, y: int, scale: float, seed_value: int) -> float:
	var v := _value_noise(x / scale, y / scale, seed_value) * 0.65
	v += _value_noise(x / (scale * 0.5), y / (scale * 0.5), seed_value + 17) * 0.35
	return v


static func _value_noise(fx: float, fy: float, seed_value: int) -> float:
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := _smooth(fx - x0)
	var ty := _smooth(fy - y0)
	var a := SeededRng.hash_unit(x0, y0, seed_value)
	var b := SeededRng.hash_unit(x0 + 1, y0, seed_value)
	var c := SeededRng.hash_unit(x0, y0 + 1, seed_value)
	var d := SeededRng.hash_unit(x0 + 1, y0 + 1, seed_value)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
