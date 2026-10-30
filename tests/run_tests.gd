extends SceneTree
## Headless unit-test runner with no addons needed:
##   godot --headless --path . --script res://tests/run_tests.gd
## Runs every test_*.gd under res://tests/unit and exits with code 1 if any test fails.
## GDScript runtime errors can't be caught here; they print "SCRIPT ERROR", which CI also treats as failure.

const TestSuite := preload("res://tests/test_suite.gd")
const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var passed := 0
	var failed := 0

	for path in _find_test_scripts(TEST_DIR):
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL  %s: script failed to load" % path)
			failed += 1
			continue

		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue

			var suite: TestSuite = script.new()
			suite.before_each()
			suite.call(test_name)
			suite.after_each()

			if suite.failures.is_empty():
				passed += 1
				print("ok    %s::%s" % [path.get_file(), test_name])
			else:
				failed += 1
				for failure in suite.failures:
					print("FAIL  %s::%s: %s" % [path.get_file(), test_name, failure])

	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _find_test_scripts(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_find_test_scripts(dir.path_join(sub)))
	return found
