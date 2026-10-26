extends RefCounted
## Daily needs: citizens eat, go hungry, emigrate after prolonged starvation, and newcomers
## arrive when food and housing allow. Agents carry no goods in or out of the settlement.

const Agent = preload("res://population/agent.gd")
const Q = preload("res://economy/stock_queries.gd")

const FOOD_PER_DAY := 1
const STARVATION_DAYS := 3
const GROWTH_FOOD_DAYS := 3


static func daily(s) -> void:
	for fid in s.factions.size():
		_feed(s, fid)
		_grow(s, fid)
		_house_homeless(s, fid)


static func _feed(s, fid: int) -> void:
	var leaving := []
	for a in s.faction_agents(fid):
		if _eat(s, a):
			a.hunger_days = 0
		else:
			a.hunger_days += 1
			if a.hunger_days >= STARVATION_DAYS:
				leaving.append(a)
	for a in leaving:
		var drop = s.buildings.get(a.home)
		if drop == null:
			drop = Q.nearest(Q.storages(s, fid), a.pos)
		if drop != null:
			s.ledger.transfer_all(a.id, drop.id)
		s.remove_agent(a.id)
		s.log_event("A starving citizen left %s" % s.faction(fid).name)


static func _eat(s, a) -> bool:
	if s.ledger.consume(a.home, "food", FOOD_PER_DAY):
		return true
	var sources := []
	for b in s.faction_buildings(a.faction):
		if s.ledger.amount(b.id, "food") >= FOOD_PER_DAY:
			sources.append(b)
	var src = Q.nearest(sources, a.pos)
	return src != null and s.ledger.consume(src.id, "food", FOOD_PER_DAY)


static func _grow(s, fid: int) -> void:
	var pop: int = s.faction_agents(fid).size()
	var house = Q.house_with_space(s, fid)
	var hall = s.buildings.get(s.faction(fid).town_hall)
	if house == null or hall == null:
		return
	if Q.food_total(s, fid) < (pop + 1) * GROWTH_FOOD_DAYS:
		return
	var a := Agent.new(s.new_id(), fid, hall.pos)
	a.home = house.id
	s.add_agent(a)
	s.log_event("A new family settled in %s" % s.faction(fid).name)


static func _house_homeless(s, fid: int) -> void:
	for a in s.faction_agents(fid):
		if s.buildings.has(a.home):
			continue
		var house = Q.house_with_space(s, fid)
		if house == null:
			return
		a.home = house.id
