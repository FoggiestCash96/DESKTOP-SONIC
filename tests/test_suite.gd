extends RefCounted
## Base class for unit tests run by tests/run_tests.gd.
## Extend it with `extends "res://tests/test_suite.gd"`, write methods named test_*,
## and check results with the assert_* helpers. Each test gets a fresh instance.

## Failure messages recorded by the current test. The runner reads these.
var failures: PackedStringArray = []


## Runs before each test method. Override to set up shared state.
func before_each() -> void:
	pass


## Runs after each test method. Override to free anything before_each created.
func after_each() -> void:
	pass


## Records a failure unconditionally, for checks that don't fit an assert_* helper.
func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same_value(actual, expected):
		_fail("expected %s, got %s" % [var_to_str(expected), var_to_str(actual)], message)


func assert_almost_eq(actual: float, expected: float, epsilon: float = 1e-5, message: String = "") -> void:
	if absf(actual - expected) > epsilon:
		_fail("expected %s ± %s, got %s" % [expected, epsilon, actual], message)


func _same_value(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) != typeof(b) and not (typeof(a) in numeric and typeof(b) in numeric):
		return false
	return a == b


func _fail(detail: String, message: String) -> void:
	failures.append(detail if message.is_empty() else "%s (%s)" % [message, detail])
