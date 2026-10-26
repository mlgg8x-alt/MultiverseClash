extends RefCounted
## Assigns each citizen a role: workers fill production slots, builders staff construction
## sites whose materials have arrived, and everyone else hauls. Existing assignments are kept
## when still needed so agents do not thrash between jobs.

const Defs = preload("res://economy/defs.gd")
const Agent = preload("res://population/agent.gd")
const Q = preload("res://economy/stock_queries.gd")
const AgentSystem = preload("res://logistics/agent_system.gd")
const ConstructionSystem = preload("res://economy/construction_system.gd")
const ProductionSystem = preload("res://economy/production_system.gd")

const BUILDERS_PER_SITE := 2
const HAULER_SHARE := 4   # at least one hauler per this many citizens
const FOOD_TARGET_DAYS := 10
const STOCK_TARGET := 80


static func allocate(s, fid: int) -> void:
	var agents: Array = s.faction_agents(fid)
	if agents.is_empty():
		return
	var free := []
	for a in agents:
		# Agents carrying goods finish their delivery before taking another job.
		if a.task.get("type", "") in ["haul", "return_cargo"] or AgentSystem.carrying(s, a):
			a.role = Agent.ROLE_HAULER
			a.assignment = -1
		else:
			free.append(a)
	var busy_haulers := agents.size() - free.size()
	var reserved_haulers := maxi(0, maxi(1, agents.size() / HAULER_SHARE) - busy_haulers)
	var budget := free.size() - reserved_haulers
	var unassigned := free.duplicate()
	# Fill slots strictly in priority order: keep agents already doing the job, then take the
	# nearest remaining agent, preferring those without a job.
	for slot in _slots(s, fid):
		var b = slot[0]
		var role: String = slot[1]
		var staff := []
		for a in unassigned:
			if staff.size() < slot[2] and staff.size() < budget and a.assignment == b.id and a.role == role:
				staff.append(a)
		for a in staff:
			unassigned.erase(a)
		while staff.size() < slot[2] and budget - staff.size() > 0 and not unassigned.is_empty():
			var best = null
			var best_score := 1 << 30
			for a in unassigned:
				var score := Q.manhattan(a.pos, b.pos) + (0 if a.assignment == -1 else 1000)
				if score < best_score:
					best_score = score
					best = a
			staff.append(best)
			unassigned.erase(best)
		budget -= staff.size()
		for a in staff:
			_set_job(s, a, role, b)
	for a in unassigned:
		if a.role != Agent.ROLE_HAULER:
			a.role = Agent.ROLE_HAULER
			a.assignment = -1
			a.task = {}
			a.path.clear()


## Ordered [building, role, count] job slots for a faction.
static func _slots(s, fid: int) -> Array:
	var farms := []
	var sites := []
	var others := []
	for b in s.faction_buildings(fid):
		if not b.built:
			if ConstructionSystem.materials_complete(s, b):
				sites.append([b, Agent.ROLE_BUILDER, BUILDERS_PER_SITE])
			continue
		var recipe := Defs.recipe_for(b.type)
		if recipe.is_empty():
			continue
		var blocked: bool = not b.cycle_active and b.status in [
			ProductionSystem.STATUS_MISSING_INPUT, ProductionSystem.STATUS_OUTPUT_FULL]
		if blocked or _outputs_stocked(s, fid, recipe):
			continue
		var slot := [b, Agent.ROLE_WORKER, recipe["workers"]]
		if b.type == "farm":
			farms.append(slot)
		else:
			others.append(slot)
	return farms + sites + others


## True when every output of the recipe is already above the faction's stock target, so the
## labor is better spent elsewhere.
static func _outputs_stocked(s, fid: int, recipe: Dictionary) -> bool:
	for res in recipe["outputs"]:
		if Q.faction_stock(s, fid, res) < stock_target(s, fid, res):
			return false
	return true


static func stock_target(s, fid: int, res: String) -> int:
	if res == "food":
		return FOOD_TARGET_DAYS * maxi(s.faction_agents(fid).size(), 1)
	return STOCK_TARGET


static func _set_job(s, a, role: String, b) -> void:
	if a.role == role and a.assignment == b.id and not a.task.is_empty():
		return
	a.role = role
	a.assignment = b.id
	var task_type := "build" if role == Agent.ROLE_BUILDER else "work"
	if not AgentSystem.assign_task(s, a, {"type": task_type, "building": b.id}, b.pos):
		a.role = Agent.ROLE_HAULER
		a.assignment = -1
