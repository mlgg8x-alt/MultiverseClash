extends RefCounted
## Turns construction sites into buildings once materials are delivered and builders have
## worked on them. Materials are consumed into the structure on completion.

const Defs = preload("res://economy/defs.gd")
const ProductionSystem = preload("res://economy/production_system.gd")

const STATUS_AWAITING_MATERIALS := "awaiting_materials"
const STATUS_NO_BUILDERS := "no_builders"
const STATUS_CONSTRUCTING := "constructing"


static func update(s) -> void:
	var work := ProductionSystem.present_work(s, "build")
	for b in s.buildings.values():
		if b.built:
			continue
		if not materials_complete(s, b):
			b.status = STATUS_AWAITING_MATERIALS
			continue
		var w: int = work.get(b.id, 0)
		if w == 0:
			b.status = STATUS_NO_BUILDERS
			continue
		b.status = STATUS_CONSTRUCTING
		b.progress += w
		if b.progress >= Defs.building(b.type)["build_work"] * 10:
			var cost: Dictionary = Defs.building(b.type)["cost"]
			for res in cost:
				s.ledger.consume(b.id, res, cost[res])
			b.built = true
			b.progress = 0
			b.status = ""
			s.log_event("%s completed a %s" % [s.faction(b.faction).name, Defs.building(b.type)["name"]])


static func missing_materials(s, b) -> Dictionary:
	var out := {}
	var cost: Dictionary = Defs.building(b.type)["cost"]
	for res in cost:
		var n: int = cost[res] - s.ledger.amount(b.id, res)
		if n > 0:
			out[res] = n
	return out


static func materials_complete(s, b) -> bool:
	return missing_materials(s, b).is_empty()
