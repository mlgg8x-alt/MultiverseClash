extends SceneTree
## Prints a daily economy report for an all-AI game:
##   godot --headless --path . -s res://tools/report.gd -- [seed] [days]

const Simulation = preload("res://core/simulation.gd")
const Q = preload("res://economy/stock_queries.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var days := int(args[1]) if args.size() > 1 else 30
	var s = Simulation.new_game(seed_value, true)
	for d in days:
		Simulation.run(s, s.TICKS_PER_DAY)
		for f in s.factions:
			var counts := {}
			var statuses := {}
			for b in s.faction_buildings(f.id):
				var key: String = b.type if b.built else b.type + "*"
				counts[key] = counts.get(key, 0) + 1
				if b.status != "":
					statuses[b.status] = statuses.get(b.status, 0) + 1
			var roles := {}
			var hungry := 0
			for a in s.faction_agents(f.id):
				roles[a.role] = roles.get(a.role, 0) + 1
				if a.hunger_days > 0:
					hungry += 1
			var stock := {}
			for res in ["food", "timber", "stone", "iron_ore", "tools"]:
				stock[res] = Q.faction_stock(s, f.id, res)
			print("day %2d %-16s pop %2d hungry %d food %d | %s | %s | %s | %s" % [d + 1, f.name,
				s.faction_agents(f.id).size(), hungry, Q.food_total(s, f.id), stock, roles, counts, statuses])
	print("conservation errors: ", s.ledger.conservation_errors())
	quit()
