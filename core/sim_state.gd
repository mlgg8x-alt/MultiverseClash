extends RefCounted
## Complete authoritative simulation state. Plain data, independent from scene Nodes, so it can
## be stepped headless, hashed, and saved.

const SeededRng = preload("res://core/seeded_rng.gd")
const LocalMap = preload("res://world/local_map.gd")
const Ledger = preload("res://economy/ledger.gd")
const Building = preload("res://economy/building.gd")
const Agent = preload("res://population/agent.gd")
const Faction = preload("res://factions/faction.gd")

const SAVE_VERSION := 1
const GENERATION_VERSION := 1
const TICKS_PER_DAY := 200
const MAX_EVENTS := 64

var seed_value: int = 0
var tick: int = 0
var rng := SeededRng.new()
var map: LocalMap
var ledger := Ledger.new()
var factions: Array = []
var buildings: Dictionary = {}   # id -> Building, insertion order == id order
var agents: Dictionary = {}      # id -> Agent, insertion order == id order
var next_id: int = 1
var events: Array = []
var pending_commands: Array = []

var _occupancy: Dictionary = {}  # Vector2i -> building id (derived, not saved)


func new_id() -> int:
	var id := next_id
	next_id += 1
	return id


func day() -> int:
	return tick / TICKS_PER_DAY


func log_event(text: String) -> void:
	events.append("[day %d] %s" % [day() + 1, text])
	if events.size() > MAX_EVENTS:
		events.pop_front()


func add_building(b: Building) -> void:
	buildings[b.id] = b
	_occupancy[b.pos] = b.id


func building_at(pos: Vector2i) -> Building:
	var id: int = _occupancy.get(pos, -1)
	return buildings.get(id)


func add_agent(a: Agent) -> void:
	agents[a.id] = a


func remove_agent(id: int) -> void:
	ledger.remove_owner(id)
	agents.erase(id)


func faction(fid: int) -> Faction:
	return factions[fid]


func faction_buildings(fid: int, type: String = "") -> Array:
	var out := []
	for b in buildings.values():
		if b.faction == fid and (type == "" or b.type == type):
			out.append(b)
	return out


func faction_agents(fid: int) -> Array:
	var out := []
	for a in agents.values():
		if a.faction == fid:
			out.append(a)
	return out


func serialize() -> Dictionary:
	var b_list := []
	for b in buildings.values():
		b_list.append(b.to_dict())
	var a_list := []
	for a in agents.values():
		a_list.append(a.to_dict())
	var f_list := []
	for f in factions:
		f_list.append(f.to_dict())
	return {
		"save_version": SAVE_VERSION,
		"generation_version": GENERATION_VERSION,
		"seed": seed_value,
		"tick": tick,
		"rng_state": rng.state,
		"next_id": next_id,
		"map": map.to_dict(),
		"ledger": ledger.to_dict(),
		"factions": f_list,
		"buildings": b_list,
		"agents": a_list,
		"events": events.duplicate(),
		"pending_commands": pending_commands.duplicate(true),
	}


## Loads a dictionary produced by `serialize` (possibly after a JSON round trip, which turns
## every number into a float, so all numeric fields are converted back to int here).
func load_from(d: Dictionary) -> void:
	seed_value = int(d["seed"])
	tick = int(d["tick"])
	rng.state = int(d["rng_state"])
	next_id = int(d["next_id"])
	map = LocalMap.from_dict(d["map"])
	ledger = Ledger.from_dict(d["ledger"])
	factions = []
	for fd in d["factions"]:
		factions.append(Faction.from_dict(fd))
	buildings = {}
	_occupancy = {}
	for bd in d["buildings"]:
		add_building(Building.from_dict(bd))
	agents = {}
	for ad in d["agents"]:
		add_agent(Agent.from_dict(ad))
	events = []
	for e in d.get("events", []):
		events.append(str(e))
	pending_commands = []
	for c in d.get("pending_commands", []):
		pending_commands.append(_normalize_numbers(c))


static func _normalize_numbers(v: Variant) -> Variant:
	if v is float:
		return int(v)
	if v is Array:
		var out := []
		for x in v:
			out.append(_normalize_numbers(x))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _normalize_numbers(v[k])
		return out
	return v
