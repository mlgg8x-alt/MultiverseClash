extends RefCounted
## A visible representative citizen. Carried cargo lives in the ledger under the agent's id.

const ROLE_IDLE := "idle"
const ROLE_WORKER := "worker"
const ROLE_BUILDER := "builder"
const ROLE_HAULER := "hauler"

var id: int
var faction: int
var home := -1
var pos: Vector2i
var role := ROLE_IDLE
var assignment := -1             # building id for workers and builders
var task: Dictionary = {}        # see logistics/agent_system.gd for task shapes
var path: Array[Vector2i] = []
var hunger_days := 0


func _init(p_id: int = 0, p_faction: int = 0, p_pos := Vector2i.ZERO) -> void:
	id = p_id
	faction = p_faction
	pos = p_pos


## Work points contributed per tick; hunger halves productivity.
func work_rate() -> int:
	return 10 if hunger_days == 0 else 5


func to_dict() -> Dictionary:
	var flat := []
	for p in path:
		flat.append_array([p.x, p.y])
	return {"id": id, "faction": faction, "home": home, "pos": [pos.x, pos.y], "role": role,
		"assignment": assignment, "task": task.duplicate(), "path": flat, "hunger_days": hunger_days}


static func from_dict(d: Dictionary):
	var a = load("res://population/agent.gd").new(int(d["id"]), int(d["faction"]),
		Vector2i(int(d["pos"][0]), int(d["pos"][1])))
	a.home = int(d["home"])
	a.role = str(d["role"])
	a.assignment = int(d["assignment"])
	a.hunger_days = int(d["hunger_days"])
	var task := {}
	for k in d["task"]:
		var v: Variant = d["task"][k]
		task[k] = int(v) if v is float else v
	a.task = task
	var flat: Array = d["path"]
	for i in range(0, flat.size(), 2):
		a.path.append(Vector2i(int(flat[i]), int(flat[i + 1])))
	return a
