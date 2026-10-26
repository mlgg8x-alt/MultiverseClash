extends RefCounted
## Runs recipes in staffed production buildings. A cycle consumes its inputs when it starts and
## produces its outputs when enough work has been done, so shortages halt production.

const Defs = preload("res://economy/defs.gd")

const STATUS_WORKING := "working"
const STATUS_NO_WORKERS := "no_workers"
const STATUS_MISSING_INPUT := "missing_input"
const STATUS_OUTPUT_FULL := "output_full"


static func update(s) -> void:
	var work := present_work(s, "work")
	for b in s.buildings.values():
		if not b.built:
			continue
		var recipe := Defs.recipe_for(b.type)
		if recipe.is_empty():
			continue
		_update_building(s, b, recipe, work.get(b.id, 0))


## Work points per building from agents standing at it with the given task type.
static func present_work(s, task_type: String) -> Dictionary:
	var out := {}
	for a in s.agents.values():
		if a.task.get("type", "") != task_type or not a.path.is_empty():
			continue
		var b = s.buildings.get(int(a.task["building"]))
		if b != null and b.pos == a.pos:
			out[b.id] = out.get(b.id, 0) + a.work_rate()
	return out


static func output_held(s, b, recipe: Dictionary) -> int:
	var n := 0
	for res in recipe["outputs"]:
		n += s.ledger.amount(b.id, res)
	return n


static func _update_building(s, b, recipe: Dictionary, work: int) -> void:
	if not b.cycle_active:
		var cap: int = Defs.building(b.type)["output_cap"]
		if output_held(s, b, recipe) + _sum(recipe["outputs"]) > cap:
			b.status = STATUS_OUTPUT_FULL
			return
		for res in recipe["inputs"]:
			if s.ledger.amount(b.id, res) < recipe["inputs"][res]:
				b.status = STATUS_MISSING_INPUT
				return
		if work == 0:
			b.status = STATUS_NO_WORKERS
			return
		for res in recipe["inputs"]:
			s.ledger.consume(b.id, res, recipe["inputs"][res])
		b.cycle_active = true
		b.progress = 0
	if work == 0:
		b.status = STATUS_NO_WORKERS
		return
	b.status = STATUS_WORKING
	b.progress += work
	if b.progress >= recipe["work"] * 10:
		for res in recipe["outputs"]:
			s.ledger.produce(b.id, res, recipe["outputs"][res])
		for res in recipe["byproducts"]:
			s.ledger.produce(b.id, res, recipe["byproducts"][res])
		b.cycle_active = false
		b.progress = 0


static func _sum(d: Dictionary) -> int:
	var n := 0
	for v in d.values():
		n += v
	return n
