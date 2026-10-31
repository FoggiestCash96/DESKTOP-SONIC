class_name MenuKit
extends RefCounted
## Helpers the menus share for building their controls. The look comes from menu_theme.tres; text
## given as a translation key (such as "MENU_PLAY") is translated as it shows.

const YELLOW := Color(1.0, 0.82, 0.25)
const NAVY := Color(0.024, 0.063, 0.227)


static func button(text: String, on_pressed: Callable) -> Button:
	var made := Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_ALL
	made.pressed.connect(on_pressed)
	return made


static func label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var made := Label.new()
	made.text = text
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	made.add_theme_color_override("font_outline_color", NAVY)
	made.add_theme_constant_override("outline_size", maxi(floori(font_size / 6.0), 4))
	return made


## Gives focus to the first control under `root` that can take it and isn't disabled.
static func focus_first(root: Node) -> void:
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree() and not (control is BaseButton and (control as BaseButton).disabled):
			control.grab_focus()
			return
