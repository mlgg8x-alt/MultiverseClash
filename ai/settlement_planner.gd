extends RefCounted
## Rule-based settlement planner. It sees the same state and issues the same commands as a
## player, so the AI pays the same construction costs and obeys the same production rules.

const Defs = preload("res://economy/defs.gd")
const Q = preload("res://economy/stock_queries.gd")
const Commands = preload("res://core/commands.gd")
const LocalMap = preload("res://world/local_map.gd")

const PLAN_INTERVAL := 100
const SEARCH_RADIUS := 14
const PEOPLE_PER_FARM := 6


static func plan(s, fid: int) -> void:
	for b in s.faction_buildings(fid):
		if not b.built:
			return   # one project at a time keeps labor and materials focused
	for type in priorities(s, fid):
		if not _affordable(s, fid, type):
			continue
		var pos = find_site(s, fid, type)
		if pos != null:
			s.pending_commands.append(Commands.place_building(fid, type, pos))
			return


## Building types the faction wants, most urgent first.
static func priorities(s, fid: int) -> Array:
	var pop: int = s.faction_agents(fid).size()
	var counts := {}
	for b in s.faction_buildings(fid):
		counts[b.type] = counts.get(b.type, 0) + 1
	var free_housing := Q.housing_capacity(s, fid) - pop
	var storage := Q.storage_capacity_and_used(s, fid)
	var out := []
	if counts.get("farm", 0) < ceili((pop + 1) / float(PEOPLE_PER_FARM)):
		out.append("farm")
	if counts.get("lumber_camp", 0) < 1:
		out.append("lumber_camp")
	if free_housing <= 1:
		out.append("house")
	if counts.get("quarry", 0) < 1:
		out.append("quarry")
	if storage.y * 10 > storage.x * 7:
		out.append("warehouse")
	if counts.get("lumber_camp", 0) < 1 + pop / 10:
		out.append("lumber_camp")
	if counts.get("mine", 0) < 1 and pop >= 10:
		out.append("mine")
	if counts.get("workshop", 0) < 1 and counts.get("mine", 0) >= 1:
		out.append("workshop")
	return out


static func _affordable(s, fid: int, type: String) -> bool:
	var cost: Dictionary = Defs.building(type)["cost"]
	for res in cost:
		if Q.faction_stock(s, fid, res) < cost[res]:
			return false
	return true


## Nearest valid tile to the town hall in a deterministic spiral, preferring plain grass within
## a ring so resource tiles stay free.
static func find_site(s, fid: int, type: String):
	var hall = s.buildings.get(s.faction(fid).town_hall)
	if hall == null:
		return null
	var fallback = null
	for r in range(1, SEARCH_RADIUS + 1):
		for p in _ring(hall.pos, r):
			if not s.map.in_bounds(p) or Commands.placement_error(s, fid, type, p) != "":
				continue
			if s.map.get_tile(p) == LocalMap.Terrain.GRASS:
				return p
			if fallback == null:
				fallback = p
		if fallback != null:
			return fallback
	return null


static func _ring(c: Vector2i, r: int) -> Array:
	var out := []
	for x in range(c.x - r, c.x + r + 1):
		out.append(Vector2i(x, c.y - r))
		out.append(Vector2i(x, c.y + r))
	for y in range(c.y - r + 1, c.y + r):
		out.append(Vector2i(c.x - r, y))
		out.append(Vector2i(c.x + r, y))
	return out
