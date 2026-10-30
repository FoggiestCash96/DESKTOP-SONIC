class_name Stage
extends Node3D
## Root script for a playable stage. It reports the stage to GameState, restarts it from the last
## checkpoint after a player dies, ends the game when the lives run out, moves on after the goal's
## results, and goes back to the title screen on pause.

@export var title: String = ""  ## Name shown as the stage starts and on its results, such as "Act 1: Sunny Beachfront".
@export_file("*.tscn") var next_scene: String = ""  ## Where the goal leads. Empty goes back to the title screen.

var _ending := false


func _enter_tree() -> void:
	# Before the children are ready, so the player can ask GameState where to start.
	GameState.enter_stage(scene_file_path)


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		(node as Player).died.connect(_on_player_died)
	GameState.stage_cleared.connect(_on_stage_cleared)


func _exit_tree() -> void:
	GameState.stop_clock()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_to_title()


func _on_player_died() -> void:
	if _ending:
		return
	_ending = true
	GameState.stop_clock()
	# Timers call back through signals, which are dropped if the stage is freed first (on pause).
	var next := _restart if GameState.lose_life() else _game_over
	get_tree().create_timer(GameState.rules.restart_delay).timeout.connect(next)


func _on_stage_cleared() -> void:
	_ending = true
	get_tree().create_timer(GameState.rules.results_time).timeout.connect(_move_on)


func _restart() -> void:
	get_tree().reload_current_scene()


func _game_over() -> void:
	GameState.end_game()
	get_tree().create_timer(GameState.rules.game_over_time).timeout.connect(_end_game)


func _end_game() -> void:
	GameState.new_game()
	_to_title()


func _move_on() -> void:
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	else:
		_to_title()


func _to_title() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	get_tree().change_scene_to_file(main_scene)
