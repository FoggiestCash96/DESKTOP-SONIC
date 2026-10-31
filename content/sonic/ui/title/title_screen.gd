extends Control
## Title screen. Shows the fan-game disclaimer and starts a new game on Enter, A or Start. The
## special button (F or Y) opens the greybox test room instead, and the boost button (Shift or X)
## goes straight to Act 8's boss, for testing until the stage select exists.

## Scene loaded when the player presses start: the first act.
@export_file("*.tscn") var first_scene: String = "res://content/sonic/stages/emerald_shore/act_1.tscn"
## Scene loaded with the special button: the greybox test room for trying the physics and gimmicks.
@export_file("*.tscn") var test_room: String = "res://stages/greybox/test_room.tscn"
## Scene loaded with the boost button: the act with the first boss.
@export_file("*.tscn") var boss_scene: String = "res://content/sonic/stages/emerald_shore/act_8.tscn"

@onready var _version_label: Label = %VersionLabel
@onready var _prompt_label: Label = %PromptLabel


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	_version_label.text = "v%s  ·  pre-alpha" % version

	var blink := create_tween().set_loops()
	blink.tween_property(_prompt_label, "modulate:a", 0.25, 0.6)
	blink.tween_property(_prompt_label, "modulate:a", 1.0, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	var scene := ""
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") or event.is_action_pressed("pause"):
		scene = first_scene
	elif event.is_action_pressed("special"):
		scene = test_room
	elif event.is_action_pressed("boost"):
		scene = boss_scene
	if scene == "":
		return
	get_viewport().set_input_as_handled()
	GameState.new_game()
	get_tree().change_scene_to_file(scene)
