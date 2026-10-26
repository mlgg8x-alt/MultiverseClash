extends RefCounted
## Moves agents along their paths and resolves task arrivals. Task shapes:
##   {"type": "work"|"build", "building": id}            stand at the building and work
##   {"type": "haul", "from": id, "to": id, "res": r, "amount": n, "phase": "pickup"|"deliver"}
##   {"type": "return_cargo", "to": id, "retry_at": tick} bring leftover cargo to storage

const Pathfinder = preload("res://world/pathfinder.gd")
const Q = preload("res://economy/stock_queries.gd")

const CARRY_CAPACITY := 5
const RETURN_RETRY_TICKS := 20


static func update(s) -> void:
	for a in s.agents.values():
		if not a.path.is_empty():
			a.pos = a.path.pop_front()
			continue
		match a.task.get("type", ""):
			"haul":
				_on_haul_arrival(s, a)
			"return_cargo":
				_on_return_arrival(s, a)


## Starts walking to `goal`; returns false when it cannot be reached.
static func set_destination(s, a, goal: Vector2i) -> bool:
	a.path = Pathfinder.find_path(s.map, a.pos, goal)
	return a.pos == goal or not a.path.is_empty()


static func assign_task(s, a, task: Dictionary, goal: Vector2i) -> bool:
	a.task = task
	if not set_destination(s, a, goal):
		a.task = {}
		return false
	return true


static func carrying(s, a) -> bool:
	return s.ledger.total_held(a.id) > 0


static func _on_haul_arrival(s, a) -> void:
	var t: Dictionary = a.task
	if t["phase"] == "pickup":
		var src = s.buildings.get(t["from"])
		var dst = s.buildings.get(t["to"])
		if src == null or dst == null or a.pos != src.pos:
			a.task = {}
			return
		var moved: int = s.ledger.transfer(src.id, a.id, t["res"], mini(t["amount"], CARRY_CAPACITY))
		if moved == 0:
			a.task = {}
			return
		t["amount"] = moved
		t["phase"] = "deliver"
		if not set_destination(s, a, dst.pos):
			start_return(s, a)
		return
	var dest = s.buildings.get(t["to"])
	if dest == null or a.pos != dest.pos:
		start_return(s, a)
		return
	var n: int = s.ledger.amount(a.id, t["res"])
	if Q.is_storage(dest):
		n = mini(n, maxi(Q.storage_free(s, dest), 0))
	s.ledger.transfer(a.id, dest.id, t["res"], n)
	if carrying(s, a):
		start_return(s, a)
	else:
		a.task = {}


static func start_return(s, a) -> void:
	var options := []
	for b in Q.storages(s, a.faction):
		if Q.storage_free(s, b) > 0:
			options.append(b)
	var target = Q.nearest(options, a.pos)
	if target == null:
		a.task = {"type": "return_cargo", "to": -1, "retry_at": s.tick + RETURN_RETRY_TICKS}
		a.path.clear()
		return
	if not assign_task(s, a, {"type": "return_cargo", "to": target.id, "retry_at": 0}, target.pos):
		a.task = {"type": "return_cargo", "to": -1, "retry_at": s.tick + RETURN_RETRY_TICKS}


static func _on_return_arrival(s, a) -> void:
	var t: Dictionary = a.task
	if not carrying(s, a):
		a.task = {}
		return
	var dest = s.buildings.get(t["to"])
	if dest != null and a.pos == dest.pos:
		for res in s.ledger.held(a.id).keys():
			s.ledger.transfer(a.id, dest.id, res, maxi(Q.storage_free(s, dest), 0))
		if not carrying(s, a):
			a.task = {}
			return
	elif s.tick < t["retry_at"]:
		return
	start_return(s, a)
