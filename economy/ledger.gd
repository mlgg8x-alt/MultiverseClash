extends RefCounted
## The single authoritative stock ledger. Every unit of every resource is held by exactly one
## owner (a building or agent id). Units enter only through `seed_initial` and `produce` and
## leave only through `consume`; everything else is a `transfer`, so totals are conserved.

var stocks: Dictionary = {}     # owner id -> {resource id: amount > 0}
var initial: Dictionary = {}    # resource id -> amount seeded at world creation
var produced: Dictionary = {}   # resource id -> cumulative amount produced
var consumed: Dictionary = {}   # resource id -> cumulative amount consumed


func amount(owner: int, res: String) -> int:
	return stocks.get(owner, {}).get(res, 0)


func held(owner: int) -> Dictionary:
	return stocks.get(owner, {})


func total_held(owner: int) -> int:
	var n := 0
	for v in stocks.get(owner, {}).values():
		n += v
	return n


func seed_initial(owner: int, res: String, n: int) -> void:
	assert(n >= 0)
	_add(owner, res, n)
	initial[res] = initial.get(res, 0) + n


func produce(owner: int, res: String, n: int) -> void:
	assert(n >= 0)
	_add(owner, res, n)
	produced[res] = produced.get(res, 0) + n


func consume(owner: int, res: String, n: int) -> bool:
	if amount(owner, res) < n:
		return false
	_sub(owner, res, n)
	consumed[res] = consumed.get(res, 0) + n
	return true


## Moves up to `n` units and returns how many actually moved.
func transfer(from: int, to: int, res: String, n: int) -> int:
	var moved := mini(n, amount(from, res))
	if moved <= 0:
		return 0
	_sub(from, res, moved)
	_add(to, res, moved)
	return moved


func transfer_all(from: int, to: int) -> void:
	for res in held(from).keys():
		transfer(from, to, res, amount(from, res))


## Owners may only disappear empty-handed; anything else would destroy goods.
func remove_owner(owner: int) -> void:
	assert(total_held(owner) == 0, "Removing owner %d that still holds goods" % owner)
	stocks.erase(owner)


func totals() -> Dictionary:
	var out := {}
	for inv in stocks.values():
		for res in inv:
			out[res] = out.get(res, 0) + inv[res]
	return out


## Empty when initial + produced - consumed matches what owners hold for every resource.
func conservation_errors() -> Array:
	var errors := []
	var t := totals()
	var keys := {}
	for d in [t, initial, produced, consumed]:
		for k in d:
			keys[k] = true
	for res in keys:
		var expected: int = initial.get(res, 0) + produced.get(res, 0) - consumed.get(res, 0)
		if t.get(res, 0) != expected:
			errors.append("%s: held %d, expected %d" % [res, t.get(res, 0), expected])
	for owner in stocks:
		for res in stocks[owner]:
			if stocks[owner][res] <= 0:
				errors.append("owner %d holds non-positive %s" % [owner, res])
	return errors


func _add(owner: int, res: String, n: int) -> void:
	if n == 0:
		return
	if not stocks.has(owner):
		stocks[owner] = {}
	stocks[owner][res] = stocks[owner].get(res, 0) + n


func _sub(owner: int, res: String, n: int) -> void:
	var inv: Dictionary = stocks[owner]
	inv[res] -= n
	if inv[res] == 0:
		inv.erase(res)
	if inv.is_empty():
		stocks.erase(owner)


func to_dict() -> Dictionary:
	var s := {}
	for owner in stocks:
		s[str(owner)] = stocks[owner].duplicate()
	return {"stocks": s, "initial": initial.duplicate(), "produced": produced.duplicate(),
		"consumed": consumed.duplicate()}


static func from_dict(d: Dictionary):
	var l = load("res://economy/ledger.gd").new()
	for owner in d["stocks"]:
		var inv := {}
		for res in d["stocks"][owner]:
			inv[str(res)] = int(d["stocks"][owner][res])
		l.stocks[int(owner)] = inv
	for field in ["initial", "produced", "consumed"]:
		var out := {}
		for res in d[field]:
			out[str(res)] = int(d[field][res])
		l.set(field, out)
	return l
