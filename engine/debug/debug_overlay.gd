extends CanvasLayer
## Developer overlay, toggled with the debug_overlay action (F3 by default).
## Autoloaded as DebugOverlay. Any script can show a live value with
## DebugOverlay.watch("label", getter) and remove it with DebugOverlay.unwatch("label").

var _watches: Dictionary[String, Callable] = {}

@onready var _text: Label = %Text


func _ready() -> void:
	visible = false


func watch(label: String, getter: Callable) -> void:
	_watches[label] = getter


func unwatch(label: String) -> void:
	_watches.erase(label)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return

	var fps := Engine.get_frames_per_second()
	var scene := get_tree().current_scene
	var lines: PackedStringArray = [
		"FPS %d  (%.1f ms)" % [fps, 1000.0 / maxf(fps, 1.0)],
		"Physics %d Hz  |  %s  |  interpolation %s" % [
			Engine.physics_ticks_per_second,
			ProjectSettings.get_setting("physics/3d/physics_engine"),
			"on" if get_tree().physics_interpolation else "off",
		],
		"Scene %s" % (scene.scene_file_path.get_file() if scene else "-"),
	]

	# Watches whose owner was freed are dropped instead of printing errors.
	var dead: PackedStringArray = []
	for label: String in _watches:
		var getter := _watches[label]
		if getter.is_valid():
			lines.append("%s: %s" % [label, str(getter.call())])
		else:
			dead.append(label)
	for label in dead:
		_watches.erase(label)

	_text.text = "\n".join(lines)
