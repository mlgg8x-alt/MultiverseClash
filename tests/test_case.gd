extends RefCounted
## Minimal assertion helpers for the headless test runner.

var failures: Array = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (got %s, expected %s)" % [message, actual, expected])
