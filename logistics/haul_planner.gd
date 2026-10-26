extends RefCounted
## Matches delivery requests (construction materials, household food, recipe inputs) and
## output-clearing requests with idle haulers. In-flight tasks are counted so goods are never
## double-booked.

const Defs = preload("res://economy/defs.gd")
const Q = preload("res://economy/stock_queries.gd")
const AgentSystem = preload("res://logistics/agent_system.gd")
const ConstructionSystem = preload("res://economy/construction_system.gd")
const ProductionSystem = preload("res://economy/production_system.gd")

const FOOD_PER_RESIDENT := 2
const INPUT_BATCHES := 2
const MIN_CLEAR_LOAD := 3


static func plan(s, fid: int) -> void:
	var idle := []
	for a in s.faction_agents(fid):
		if a.role == "hauler" and a.task.is_empty():
			idle.append(a)
	if idle.is_empty():
		return
	var incoming := {}   # "to:res" -> n, and "to" -> n for storage capacity
	var outgoing := {}   # "from:res" -> n
	for a in s.faction_agents(fid):
		var t: Dictionary = a.task
		if t.get("type", "") == "haul":
			_add(incoming, "%d:%s" % [t["to"], t["res"]], t["amount"])
			_add(incoming, str(t["to"]), t["amount"])
			if t["phase"] == "pickup":
				_add(outgoing, "%d:%s" % [t["from"], t["res"]], t["amount"])
		elif t.get("type", "") == "return_cargo":
			_add(incoming, str(t["to"]), s.ledger.total_held(a.id))

	var deliveries := []   # [building, res, need]
	var clears := []       # [building, res, have]
	var buildings: Array = s.faction_buildings(fid)
	for b in buildings:
		if b.type == "house" and b.built:
			var target := Q.residents(s, b.id) * FOOD_PER_RESIDENT
			deliveries.append([b, "food", target - s.ledger.amount(b.id, "food")])
	for b in buildings:
		if not b.built:
			var missing := ConstructionSystem.missing_materials(s, b)
			for res in missing:
				deliveries.append([b, res, missing[res]])
	for b in buildings:
		if not b.built:
			continue
		var recipe := Defs.recipe_for(b.type)
		if recipe.is_empty():
			continue
		for res in recipe["inputs"]:
			deliveries.append([b, res, recipe["inputs"][res] * INPUT_BATCHES - s.ledger.amount(b.id, res)])
		for res in recipe["outputs"]:
			var have: int = s.ledger.amount(b.id, res)
			if have >= MIN_CLEAR_LOAD or b.status == ProductionSystem.STATUS_OUTPUT_FULL:
				clears.append([b, res, have])

	for req in deliveries:
		if idle.is_empty():
			return
		var dest = req[0]
		var res: String = req[1]
		var need: int = req[2] - incoming.get("%d:%s" % [dest.id, res], 0)
		if need <= 0:
			continue
		var sources := []
		for b in buildings:
			if b.id != dest.id and (Q.is_storage(b) or Q.produces(b, res)):
				if s.ledger.amount(b.id, res) - outgoing.get("%d:%s" % [b.id, res], 0) > 0:
					sources.append(b)
		var src = Q.nearest(sources, dest.pos)
		if src == null:
			continue
		var avail: int = s.ledger.amount(src.id, res) - outgoing.get("%d:%s" % [src.id, res], 0)
		var n := mini(mini(need, avail), AgentSystem.CARRY_CAPACITY)
		if _dispatch(s, idle, src, dest, res, n):
			_add(incoming, "%d:%s" % [dest.id, res], n)
			_add(incoming, str(dest.id), n)
			_add(outgoing, "%d:%s" % [src.id, res], n)

	for req in clears:
		if idle.is_empty():
			return
		var src = req[0]
		var res: String = req[1]
		var avail: int = req[2] - outgoing.get("%d:%s" % [src.id, res], 0)
		if avail <= 0:
			continue
		var options := []
		for b in Q.storages(s, fid):
			if Q.storage_free(s, b) - incoming.get(str(b.id), 0) > 0:
				options.append(b)
		var dest = Q.nearest(options, src.pos)
		if dest == null:
			continue
		var free: int = Q.storage_free(s, dest) - incoming.get(str(dest.id), 0)
		var n := mini(mini(avail, free), AgentSystem.CARRY_CAPACITY)
		if _dispatch(s, idle, src, dest, res, n):
			_add(incoming, "%d:%s" % [dest.id, res], n)
			_add(incoming, str(dest.id), n)
			_add(outgoing, "%d:%s" % [src.id, res], n)


static func _dispatch(s, idle: Array, src, dest, res: String, n: int) -> bool:
	if n <= 0:
		return false
	var best = null
	var best_d := 1 << 30
	for a in idle:
		var d := Q.manhattan(a.pos, src.pos)
		if d < best_d:
			best_d = d
			best = a
	var task := {"type": "haul", "from": src.id, "to": dest.id, "res": res, "amount": n, "phase": "pickup"}
	idle.erase(best)
	return AgentSystem.assign_task(s, best, task, src.pos)


static func _add(d: Dictionary, key: String, n: int) -> void:
	d[key] = d.get(key, 0) + n
