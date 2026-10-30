class_name Stage
extends Node3D
## Root script for a playable stage. It reports the stage to GameState, restarts it from the last
## checkpoint after a player dies, ends the game when the lives run out, and goes back to the title
## screen on pause.

var _ending := false


func _enter_tree() -> void:
	# Before the children are ready, so the player can ask GameState where to start.
	GameState.enter_stage(scene_file_path)


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		(node as Player).died.connect(_on_player_died)


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


func _restart() -> void:
	get_tree().reload_current_scene()


func _game_over() -> void:
	GameState.end_game()
	get_tree().create_timer(GameState.rules.game_over_time).timeout.connect(_end_game)


func _end_game() -> void:
	GameState.new_game()
	_to_title()


func _to_title() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	get_tree().change_scene_to_file(main_scene)
