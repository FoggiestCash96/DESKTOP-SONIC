extends SceneTree
## Compiles every GDScript file in the project with all enabled warnings raised to errors:
##   godot --headless --path . --script res://tests/check_scripts.gd
## Exits with code 1 if any script has a parse error or a warning (project rule: no warnings).
##
## Godot reads warning levels only at startup, so this writes a temporary override.cfg that
## raises them, runs itself again in a child process to do the compiling, then deletes the file.

const SKIPPED_DIRS: PackedStringArray = [".godot", "addons", "build"]
const OVERRIDE_PATH := "res://override.cfg"
const CHILD_FLAG := "--compile-scripts"


func _initialize() -> void:
	if CHILD_FLAG in OS.get_cmdline_user_args():
		quit(_compile_all())
	else:
		quit(_run_child_with_strict_warnings())


func _run_child_with_strict_warnings() -> int:
	var override_file := ProjectSettings.globalize_path(OVERRIDE_PATH)
	if FileAccess.file_exists(override_file):
		printerr("override.cfg already exists; move it aside and run again.")
		return 1

	var strict := ConfigFile.new()
	for property in ProjectSettings.get_property_list():
		var setting: String = property["name"]
		var prefix := "debug/gdscript/warnings/"
		if setting.begins_with(prefix) and ProjectSettings.get_setting(setting) is int:
			if ProjectSettings.get_setting(setting) == 1:  # 1 = warn, 2 = error.
				strict.set_value("debug", setting.trim_prefix("debug/"), 2)
	if strict.save(override_file) != OK:
		printerr("Could not write %s" % override_file)
		return 1

	var output: Array = []
	var args := PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", (get_script() as Script).resource_path, "--", CHILD_FLAG,
	])
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	DirAccess.remove_absolute(override_file)

	for chunk: String in output:
		print(chunk.strip_edges())
	return exit_code


func _compile_all() -> int:
	var failed := 0
	var scripts := _find_scripts("res://")
	# Recompiling the script that is currently running crashes the engine, so skip this file.
	scripts.erase((get_script() as Script).resource_path)
	for path in scripts:
		var script := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL  %s" % path)

	print("%d scripts checked, %d with errors or warnings" % [scripts.size(), failed])
	return 1 if failed > 0 else 0


func _find_scripts(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		if sub not in SKIPPED_DIRS:
			found.append_array(_find_scripts(dir.path_join(sub)))
	return found
