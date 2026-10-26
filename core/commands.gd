extends RefCounted
## Player and AI intentions enter the simulation only as commands applied at the start of a
## tick, which keeps runs reproducible and replayable.

const Defs = preload("res://economy/defs.gd")
const Building = preload("res://economy/building.gd")
const LocalMap = preload("res://world/local_map.gd")

const TERRAIN_RADIUS := 3
const MAX_SITES_PER_FACTION := 3


static func place_building(fid: int, type: String, pos: Vector2i) -> Dictionary:
	return {"type": "place", "faction": fid, "building": type, "pos": [pos.x, pos.y]}


static func apply_all(s) -> void:
	for cmd in s.pending_commands:
		var err := apply(s, cmd)
		if err != "" and not s.faction(int(cmd["faction"])).is_ai:
			s.log_event("Cannot build: " + err)
	s.pending_commands.clear()


## Applies one command, returning an error message or "" on success.
static func apply(s, cmd: Dictionary) -> String:
	match cmd.get("type", ""):
		"place":
			var pos := Vector2i(int(cmd["pos"][0]), int(cmd["pos"][1]))
			var fid := int(cmd["faction"])
			var err := placement_error(s, fid, str(cmd["building"]), pos)
			if err != "":
				return err
			s.add_building(Building.new(s.new_id(), fid, str(cmd["building"]), pos))
			return ""
	return "unknown command"


static func placement_error(s, fid: int, type: String, pos: Vector2i) -> String:
	Defs.ensure_loaded()
	if not Defs.buildings.has(type) or type == "town_hall":
		return "unknown building type"
	if not s.map.is_passable(pos):
		return "tile is not buildable land"
	if s.building_at(pos) != null:
		return "tile is occupied"
	var hall = s.buildings.get(s.faction(fid).town_hall)
	if hall == null or s.map.region_of(hall.pos) != s.map.region_of(pos):
		return "tile is not reachable from the town hall"
	var sites := 0
	for b in s.faction_buildings(fid):
		if not b.built:
			sites += 1
	if sites >= MAX_SITES_PER_FACTION:
		return "too many construction sites"
	var def := Defs.building(type)
	if def["terrain"] != "":
		var terrain: int = LocalMap.TERRAIN_IDS[def["terrain"]]
		if s.map.count_in_radius(pos, terrain, TERRAIN_RADIUS) < def["terrain_min"]:
			return "needs %d %s tiles nearby" % [def["terrain_min"], def["terrain"]]
	return ""
