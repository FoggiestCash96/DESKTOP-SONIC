extends "res://tests/test_suite.gd"
## Guards the text's characters (docs/DESIGN.md, section 10.5): the project names a symbol font
## for the characters the default font lacks, and every character on a sign in a stage, and in the
## game's text, is in the default font or the symbol font. A character in neither would come from
## the player's system fonts, and show as a box where they have none.

const STAGES: Array[String] = ["res://content/sonic/stages", "res://stages"]
const STRINGS := "res://content/sonic/ui/translations/strings.csv"


func test_the_project_names_a_symbol_font_with_the_signs_arrows() -> void:
	var symbols := SymbolFont.font()
	assert_true(symbols != null, "game/ui/symbol_font names a font that loads")
	if symbols == null:
		return
	for arrow in "←→↑↓↖↗↘↙":
		assert_true(symbols.has_char(arrow.unicode_at(0)), "the symbol font has %s" % arrow)


func test_installing_it_gives_the_default_font_a_fallback_once() -> void:
	var default_font := ThemeDB.fallback_font
	var before: Array[Font] = default_font.fallbacks.duplicate()
	assert_true(SymbolFont.install(), "installs")
	assert_true(SymbolFont.install(), "installs again")
	var added := default_font.fallbacks.size() - before.size()
	assert_true(default_font.fallbacks.has(SymbolFont.font()), "the default font falls back on the symbol font")
	assert_true(added <= 1, "added once, not twice (%d added)" % added)
	default_font.fallbacks = before


func test_every_sign_in_a_stage_has_its_characters() -> void:
	var missing := {}
	for folder in STAGES:
		for scene in _scenes(folder):
			var state := (load(scene) as PackedScene).get_state()
			for i in state.get_node_count():
				if state.get_node_type(i) != &"Label3D":
					continue
				for c in _missing_characters(str(_value(state, i, &"text"))):
					missing[c] = "%s (%s)" % [scene.get_file(), state.get_node_name(i)]
	assert_true(missing.is_empty(), "characters in neither font: %s" % str(missing))


func test_the_games_text_has_its_characters() -> void:
	var file := FileAccess.open(STRINGS, FileAccess.READ)
	assert_true(file != null, "the strings load")
	if file == null:
		return
	var missing := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		for column in range(1, row.size()):  # Column 0 is the key.
			for c in _missing_characters(row[column]):
				missing[c] = row[0]
	assert_true(missing.is_empty(), "characters in neither font: %s" % str(missing))


# The characters in `text` that neither the default font nor the symbol font has.
func _missing_characters(text: String) -> Array[String]:
	var default_font := ThemeDB.fallback_font
	var symbols := SymbolFont.font()
	var out: Array[String] = []
	for c in text:
		var code := c.unicode_at(0)
		if code < 0x20 or c in out:
			continue
		if not default_font.has_char(code) and not (symbols != null and symbols.has_char(code)):
			out.append(c)
	return out


func _scenes(folder: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			out.append(folder.path_join(file))
	for sub in dir.get_directories():
		out.append_array(_scenes(folder.path_join(sub)))
	return out


func _value(state: SceneState, node: int, property: StringName) -> Variant:
	for i in state.get_node_property_count(node):
		if state.get_node_property_name(node, i) == property:
			return state.get_node_property_value(node, i)
	return ""
