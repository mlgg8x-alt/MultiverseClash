extends Node2D
## Playable view of the vertical slice. Reads simulation state for drawing and only changes it
## through commands, so the simulation stays the single source of truth.

const Simulation = preload("res://core/simulation.gd")
const SaveSystem = preload("res://core/save_system.gd")
const Commands = preload("res://core/commands.gd")
const Defs = preload("res://economy/defs.gd")
const LocalMap = preload("res://world/local_map.gd")
const Q = preload("res://economy/stock_queries.gd")
const ProductionSystem = preload("res://economy/production_system.gd")

const TILE := 14
const BASE_TICKS_PER_SECOND := 20.0
const SAVE_PATH := "user://savegame.json"
const PLAYER := 0
const BUILD_KEYS := ["house", "farm", "lumber_camp", "quarry", "mine", "warehouse", "workshop"]
const STATUS_COLORS := {
	ProductionSystem.STATUS_WORKING: Color("#5fd35f"),
	ProductionSystem.STATUS_NO_WORKERS: Color("#f0c040"),
	ProductionSystem.STATUS_MISSING_INPUT: Color("#ff4040"),
	ProductionSystem.STATUS_OUTPUT_FULL: Color("#ff9030"),
}

var state
var speed := 1
var paused := false
var selected := 0
var hover := Vector2i(-1, -1)
var message := ""
var _accum := 0.0
var _map_texture: ImageTexture
var _hud: Label
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(Simulation.MAP_SIZE.x * TILE + 12, 8)
	_hud.add_theme_font_size_override("font_size", 13)
	layer.add_child(_hud)
	_new_game(int(Time.get_unix_time_from_system()) % 100000)


func _new_game(seed_value: int) -> void:
	state = Simulation.new_game(seed_value)
	_rebuild_map_texture()
	message = "New world, seed %d" % seed_value


func _rebuild_map_texture() -> void:
	var img := Image.create(state.map.width, state.map.height, false, Image.FORMAT_RGBA8)
	for y in state.map.height:
		for x in state.map.width:
			img.set_pixel(x, y, LocalMap.TERRAIN_COLORS[state.map.get_tile(Vector2i(x, y))])
	_map_texture = ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if not paused:
		_accum += delta * BASE_TICKS_PER_SECOND * speed
		var steps := mini(int(_accum), 200)
		_accum -= int(_accum)
		for i in steps:
			Simulation.step(state)
	_update_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = Vector2i(event.position / TILE)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tile := Vector2i(event.position / TILE)
		if state.map.in_bounds(tile):
			var type: String = BUILD_KEYS[selected]
			var err := Commands.placement_error(state, PLAYER, type, tile)
			if err == "":
				state.pending_commands.append(Commands.place_building(PLAYER, type, tile))
				message = "Placed %s site" % Defs.building(type)["name"]
			else:
				message = "Cannot build: " + err
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
				selected = event.keycode - KEY_1
			KEY_SPACE:
				paused = not paused
			KEY_EQUAL, KEY_KP_ADD:
				speed = mini(speed * 2, 32)
			KEY_MINUS, KEY_KP_SUBTRACT:
				speed = maxi(speed / 2, 1)
			KEY_A:
				state.faction(PLAYER).is_ai = not state.faction(PLAYER).is_ai
			KEY_F5:
				var err: Error = SaveSystem.save_to_file(state, SAVE_PATH)
				message = "Saved" if err == OK else "Save failed (%d)" % err
			KEY_F9:
				var loaded = SaveSystem.load_from_file(SAVE_PATH)
				if loaded != null:
					state = loaded
					_rebuild_map_texture()
					message = "Loaded save from day %d" % (state.day() + 1)
				else:
					message = "No save to load"
			KEY_N:
				_new_game(state.seed_value + 1)


func _draw() -> void:
	var map_px := Vector2(state.map.width, state.map.height) * TILE
	draw_texture_rect(_map_texture, Rect2(Vector2.ZERO, map_px), false)
	for b in state.buildings.values():
		var r := Rect2(Vector2(b.pos) * TILE, Vector2(TILE, TILE)).grow(-1)
		var col: Color = Defs.building(b.type)["color"]
		if not b.built:
			draw_rect(r, col * Color(1, 1, 1, 0.45))
			draw_rect(r, col, false, 1.0)
		else:
			draw_rect(r, col)
		draw_rect(r.grow(1), state.faction(b.faction).color, false, 1.0)
		if STATUS_COLORS.has(b.status):
			draw_circle(r.position + Vector2(TILE - 4, 3), 2.5, STATUS_COLORS[b.status])
	for a in state.agents.values():
		var c := Vector2(a.pos) * TILE + Vector2(TILE, TILE) * 0.5
		var offset := Vector2((a.id % 3) - 1, (a.id / 3 % 3) - 1) * 3.0
		draw_circle(c + offset, 2.2, state.faction(a.faction).color.lightened(0.3))
		if state.ledger.total_held(a.id) > 0:
			draw_circle(c + offset + Vector2(0, -3), 1.5, Color.WHITE)
	if state.map.in_bounds(hover):
		draw_rect(Rect2(Vector2(hover) * TILE, Vector2(TILE, TILE)), Color(1, 1, 1, 0.8), false, 1.0)


func _update_hud() -> void:
	var lines := []
	lines.append("Day %d  tick %d   speed x%d%s" % [state.day() + 1, state.tick, speed, "  PAUSED" if paused else ""])
	lines.append("")
	lines.append("Build (click map):")
	for i in BUILD_KEYS.size():
		var def := Defs.building(BUILD_KEYS[i])
		lines.append("%s %d %s  %s" % [">" if i == selected else " ", i + 1, def["name"], _fmt(def["cost"])])
	for f in state.factions:
		lines.append("")
		lines.append("%s%s" % [f.name, " (AI)" if f.is_ai else ""])
		var agents: Array = state.faction_agents(f.id)
		var hungry := 0
		for a in agents:
			if a.hunger_days > 0:
				hungry += 1
		lines.append("  pop %d / housing %d   hungry %d" % [agents.size(), Q.housing_capacity(state, f.id), hungry])
		var stock := {}
		for res in Defs.resource_ids():
			stock[res] = Q.faction_stock(state, f.id, res)
		lines.append("  " + _fmt(stock))
		var blocked := {}
		for b in state.faction_buildings(f.id):
			if b.status in [ProductionSystem.STATUS_MISSING_INPUT, ProductionSystem.STATUS_NO_WORKERS,
					ProductionSystem.STATUS_OUTPUT_FULL, "awaiting_materials", "no_builders"]:
				blocked[b.status] = blocked.get(b.status, 0) + 1
		if not blocked.is_empty():
			lines.append("  blocked: " + _fmt(blocked))
	var b = state.building_at(hover)
	if b != null:
		lines.append("")
		lines.append("%s%s [%s]" % [Defs.building(b.type)["name"], "" if b.built else " (site)", b.status])
		lines.append("  holds " + _fmt(state.ledger.held(b.id)))
	lines.append("")
	lines.append("Recent events:")
	for i in range(maxi(0, state.events.size() - 8), state.events.size()):
		lines.append("  " + state.events[i])
	lines.append("")
	lines.append(message)
	lines.append("1-7 select  Space pause  +/- speed  A toggle autopilot")
	lines.append("F5 save  F9 load  N new world")
	_hud.text = "\n".join(lines)


static func _fmt(d: Dictionary) -> String:
	var parts := []
	for k in d:
		parts.append("%s %d" % [k, d[k]])
	return ", ".join(parts) if not parts.is_empty() else "-"
