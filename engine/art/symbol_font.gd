class_name SymbolFont
extends RefCounted
## A fallback for the characters the engine's default font doesn't have, such as the arrows on
## signs, so they look the same on every system instead of coming from whatever fonts the system
## has installed (a system without one shows boxes). The project setting game/ui/symbol_font names
## the font. Text in the default font keeps its look: only characters missing from it come from
## the symbol font.

const SETTING := "game/ui/symbol_font"


## The symbol font the project names, or null.
static func font() -> Font:
	var path: String = ProjectSettings.get_setting(SETTING, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Font


## Adds the symbol font to the default font's fallbacks, if it isn't there yet. Returns whether the
## default font has it now. The default font serves the menus, the HUD and signs alike.
static func install() -> bool:
	var symbols := font()
	var default_font := ThemeDB.fallback_font
	if symbols == null or default_font == null:
		return false
	if not default_font.fallbacks.has(symbols):
		var fallbacks: Array[Font] = default_font.fallbacks.duplicate()
		fallbacks.append(symbols)
		default_font.fallbacks = fallbacks
	return true
