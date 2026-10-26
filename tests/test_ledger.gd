extends "res://tests/test_case.gd"

const Ledger = preload("res://economy/ledger.gd")


func test_transfer_conserves_and_clamps() -> void:
	var l := Ledger.new()
	l.seed_initial(1, "food", 10)
	check_eq(l.transfer(1, 2, "food", 4), 4, "partial transfer moves requested amount")
	check_eq(l.transfer(1, 2, "food", 100), 6, "transfer clamps to available stock")
	check_eq(l.amount(1, "food"), 0, "source emptied")
	check_eq(l.amount(2, "food"), 10, "destination received everything")
	check(not l.stocks.has(1), "empty owners are pruned")
	check(l.conservation_errors().is_empty(), "no conservation errors")


func test_consume_requires_stock() -> void:
	var l := Ledger.new()
	l.seed_initial(1, "timber", 3)
	check(not l.consume(1, "timber", 4), "cannot consume more than held")
	check(l.consume(1, "timber", 3), "consume exact amount")
	l.produce(1, "timber", 2)
	check_eq(l.totals().get("timber", 0), 2, "totals reflect produce/consume")
	check(l.conservation_errors().is_empty(), "accounting balanced")


func test_detects_unaccounted_goods() -> void:
	var l := Ledger.new()
	l.seed_initial(1, "stone", 5)
	l.stocks[1]["stone"] = 7   # simulate a bug that bypasses the API
	check(not l.conservation_errors().is_empty(), "conservation check catches created goods")


func test_json_round_trip() -> void:
	var l := Ledger.new()
	l.seed_initial(3, "food", 5)
	l.produce(12, "tools", 2)
	l.consume(3, "food", 1)
	var back = Ledger.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	check_eq(back.stocks, l.stocks, "stocks survive JSON")
	check_eq(back.consumed, l.consumed, "counters survive JSON")
	check(back.conservation_errors().is_empty(), "round-tripped ledger balanced")
