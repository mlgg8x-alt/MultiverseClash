extends RefCounted
## A playable or AI-controlled civilization. Universe-specific rules will hang off `universe`.

var id: int
var name: String
var universe := "custom"
var is_ai := false
var color := Color.WHITE
var town_hall := -1


func _init(p_id: int = 0, p_name: String = "", p_is_ai := false, p_color := Color.WHITE) -> void:
	id = p_id
	name = p_name
	is_ai = p_is_ai
	color = p_color


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "universe": universe, "is_ai": is_ai,
		"color": color.to_html(false), "town_hall": town_hall}


static func from_dict(d: Dictionary):
	var f = load("res://factions/faction.gd").new(int(d["id"]), str(d["name"]), bool(d["is_ai"]),
		Color(str(d["color"])))
	f.universe = str(d["universe"])
	f.town_hall = int(d["town_hall"])
	return f
