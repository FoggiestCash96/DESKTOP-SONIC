extends Control
## Title screen. Shows the fan-game disclaimer and starts the game on Enter, A or Start.

## Scene loaded when the player presses start. Points at the greybox test room until real stages exist.
@export_file("*.tscn") var first_scene: String = "res://stages/greybox/test_room.tscn"

@onready var _version_label: Label = %VersionLabel
@onready var _prompt_label: Label = %PromptLabel


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	_version_label.text = "v%s  ·  pre-alpha" % version

	var blink := create_tween().set_loops()
	blink.tween_property(_prompt_label, "modulate:a", 0.25, 0.6)
	blink.tween_property(_prompt_label, "modulate:a", 1.0, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(first_scene)
