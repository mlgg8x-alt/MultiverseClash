extends RefCounted
## Versioned JSON save files.

const SimState = preload("res://core/sim_state.gd")


static func to_json(s: SimState) -> String:
	return JSON.stringify(s.serialize(), "\t")


static func from_json(text: String) -> SimState:
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("Save file is not a JSON object")
		return null
	data = _migrate(data)
	if data == null:
		return null
	var s := SimState.new()
	s.load_from(data)
	return s


static func save_to_file(s: SimState, path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json(s))
	return OK


static func load_from_file(path: String) -> SimState:
	if not FileAccess.file_exists(path):
		return null
	return from_json(FileAccess.get_file_as_string(path))


## Upgrades older save layouts to the current one. Add a step per version bump.
static func _migrate(data: Dictionary) -> Variant:
	var version := int(data.get("save_version", 0))
	if version > SimState.SAVE_VERSION:
		push_error("Save version %d is newer than supported %d" % [version, SimState.SAVE_VERSION])
		return null
	if version < 1:
		push_error("Unsupported save version %d" % version)
		return null
	return data
