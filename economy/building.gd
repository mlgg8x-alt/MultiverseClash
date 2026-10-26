extends RefCounted
## A placed building or construction site. Its stock lives in the ledger under its id.

var id: int
var faction: int
var type: String
var pos: Vector2i
var built := false
var progress := 0          # work points toward construction or the current production cycle
var cycle_active := false  # recipe inputs have been consumed for the current cycle
var status := ""


func _init(p_id: int = 0, p_faction: int = 0, p_type: String = "", p_pos := Vector2i.ZERO) -> void:
	id = p_id
	faction = p_faction
	type = p_type
	pos = p_pos


func to_dict() -> Dictionary:
	return {"id": id, "faction": faction, "type": type, "pos": [pos.x, pos.y], "built": built,
		"progress": progress, "cycle_active": cycle_active, "status": status}


static func from_dict(d: Dictionary):
	var b = load("res://economy/building.gd").new(int(d["id"]), int(d["faction"]), str(d["type"]),
		Vector2i(int(d["pos"][0]), int(d["pos"][1])))
	b.built = bool(d["built"])
	b.progress = int(d["progress"])
	b.cycle_active = bool(d["cycle_active"])
	b.status = str(d["status"])
	return b
