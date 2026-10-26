extends RefCounted
## Read-only registry of resources, recipes and buildings loaded from res://data.

static var resources: Dictionary = {}
static var recipes: Dictionary = {}
static var buildings: Dictionary = {}
static var _loaded := false

const DEFAULT_OUTPUT_CAP := 12


static func ensure_loaded() -> void:
	if _loaded:
		return
	resources = _load_json("res://data/resources.json")
	recipes = {}
	var raw_recipes: Dictionary = _load_json("res://data/recipes.json")
	for id in raw_recipes:
		var r: Dictionary = raw_recipes[id]
		recipes[id] = {
			"inputs": _int_dict(r.get("inputs", {})),
			"outputs": _int_dict(r.get("outputs", {})),
			"byproducts": _int_dict(r.get("byproducts", {})),
			"work": int(r["work"]),
			"workers": int(r["workers"]),
			"skill": str(r.get("skill", "")),
			"power": int(r.get("power", 0)),
			"maintenance": int(r.get("maintenance", 0)),
		}
	var raw_buildings: Dictionary = _load_json("res://data/buildings.json")
	buildings = {}
	for id in raw_buildings:
		var b: Dictionary = raw_buildings[id]
		buildings[id] = {
			"name": str(b.get("name", id)),
			"cost": _int_dict(b.get("cost", {})),
			"build_work": int(b.get("build_work", 0)),
			"storage": int(b.get("storage", 0)),
			"housing": int(b.get("housing", 0)),
			"recipe": str(b.get("recipe", "")),
			"terrain": str(b.get("terrain", "")),
			"terrain_min": int(b.get("terrain_min", 0)),
			"output_cap": int(b.get("output_cap", DEFAULT_OUTPUT_CAP)),
			"color": Color(str(b.get("color", "#ffffff"))),
		}
	_loaded = true


static func building(type: String) -> Dictionary:
	ensure_loaded()
	return buildings[type]


## Recipe of a building type, or an empty dictionary.
static func recipe_for(type: String) -> Dictionary:
	var r: String = building(type)["recipe"]
	return recipes.get(r, {})


static func resource_ids() -> Array:
	ensure_loaded()
	return resources.keys()


static func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary, "Invalid data file " + path)
	return data


static func _int_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = int(d[k])
	return out
