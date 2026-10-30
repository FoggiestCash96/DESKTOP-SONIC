extends Node3D
## Greybox test room: flat ground, 15°/30°/45° ramps, a half-pipe, steps, a wall
## and a 1 km runway with distance markers. Pause returns to the title screen.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
		get_tree().change_scene_to_file(main_scene)
