extends SceneTree
## Headless test runner:  godot --headless --path . -s res://tests/run_tests.gd
## Runs every `test_*` method of the scripts below and exits non-zero on failure.

const TEST_SCRIPTS := [
	"res://tests/test_ledger.gd",
	"res://tests/test_world.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_simulation.gd",
]


func _initialize() -> void:
	var failed := 0
	var passed := 0
	var only := OS.get_environment("TEST_FILTER")
	for path in TEST_SCRIPTS:
		for m in load(path).new().get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_") or (only != "" and not name.contains(only)):
				continue
			var t = load(path).new()
			var start := Time.get_ticks_msec()
			t.call(name)
			var ms := Time.get_ticks_msec() - start
			if t.failures.is_empty():
				passed += 1
				print("PASS %s (%d ms)" % [name, ms])
			else:
				failed += 1
				print("FAIL %s (%d ms)" % [name, ms])
				for f in t.failures:
					print("    - " + str(f))
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
