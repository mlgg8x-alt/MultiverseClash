extends RefCounted
## Read-only queries over buildings and the ledger shared by the simulation systems.

const Defs = preload("res://economy/defs.gd")


static func is_storage(b) -> bool:
	return b.built and Defs.building(b.type)["storage"] > 0


static func storage_free(s, b) -> int:
	return Defs.building(b.type)["storage"] - s.ledger.total_held(b.id)


static func storages(s, fid: int) -> Array:
	var out := []
	for b in s.faction_buildings(fid):
		if is_storage(b):
			out.append(b)
	return out


static func produces(b, res: String) -> bool:
	return b.built and Defs.recipe_for(b.type).get("outputs", {}).has(res)


## Stock available to a faction for planning: storages plus production output buffers.
static func faction_stock(s, fid: int, res: String) -> int:
	var n := 0
	for b in s.faction_buildings(fid):
		if is_storage(b) or produces(b, res):
			n += s.ledger.amount(b.id, res)
	return n


static func food_total(s, fid: int) -> int:
	var n := faction_stock(s, fid, "food")
	for h in s.faction_buildings(fid, "house"):
		n += s.ledger.amount(h.id, "food")
	return n


static func storage_capacity_and_used(s, fid: int) -> Vector2i:
	var cap := 0
	var used := 0
	for b in storages(s, fid):
		cap += Defs.building(b.type)["storage"]
		used += s.ledger.total_held(b.id)
	return Vector2i(cap, used)


static func housing_capacity(s, fid: int) -> int:
	var n := 0
	for b in s.faction_buildings(fid):
		if b.built:
			n += Defs.building(b.type)["housing"]
	return n


static func residents(s, house_id: int) -> int:
	var n := 0
	for a in s.agents.values():
		if a.home == house_id:
			n += 1
	return n


static func house_with_space(s, fid: int):
	for b in s.faction_buildings(fid):
		var cap: int = Defs.building(b.type)["housing"]
		if b.built and cap > 0 and residents(s, b.id) < cap:
			return b
	return null


static func nearest(buildings: Array, pos: Vector2i):
	var best = null
	var best_d := 1 << 30
	for b in buildings:
		var d := absi(b.pos.x - pos.x) + absi(b.pos.y - pos.y)
		if d < best_d:
			best_d = d
			best = b
	return best


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
