extends "res://tests/test_suite.gd"
## engine/ must stay free of franchise characters and trademarks, so it can be reused
## as a standalone open-source engine (docs/DESIGN.md, section 2). Franchise-specific
## material belongs in content/. This scans file names and text files under engine/.

const ENGINE_DIR := "res://engine"
const TEXT_EXTENSIONS: PackedStringArray = ["gd", "gdshader", "tscn", "tres", "cfg", "md", "txt", "json"]

## Letter-only boundaries: catches "Sonic" and "sonic_model" but not "supersonic".
const FORBIDDEN_PATTERN := "(?i)(?<![a-z])(sonic|sega|eggman|robotnik|knuckles|prower|chaos emeralds?)(?![a-z])"

var _forbidden := RegEx.create_from_string(FORBIDDEN_PATTERN)


func test_pattern_catches_names_but_not_ordinary_words() -> void:
	assert_true(_forbidden.search("var sonic_speed := 1.0") != null)
	assert_true(_forbidden.search("A SEGA logo") != null)
	assert_true(_forbidden.search("collect the Chaos Emeralds") != null)
	assert_true(_forbidden.search("supersonic boom effect") == null)
	assert_true(_forbidden.search("ultrasonic sensor") == null)


func test_engine_folder_has_no_franchise_names() -> void:
	for path in _files_under(ENGINE_DIR):
		var name_match := _forbidden.search(path.trim_prefix(ENGINE_DIR))
		if name_match:
			fail("%s: file name contains '%s'" % [path, name_match.get_string()])

		if path.get_extension() not in TEXT_EXTENSIONS:
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line_match := _forbidden.search(lines[i])
			if line_match:
				fail("%s:%d contains '%s'" % [path, i + 1, line_match.get_string()])


func _files_under(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir):
		found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_files_under(dir.path_join(sub)))
	return found
