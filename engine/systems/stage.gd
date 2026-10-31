class_name Stage
extends Node3D
## Root script for a playable stage. It reports the stage to GameState, sets the game speed, restarts
## the stage from the last checkpoint after a player dies, and ends the game when the lives run out.
## At the goal it records the clear on the save slot (SaveGame), shows the results, and moves on:
## to the world map while a save slot is being played, otherwise to `next_scene` or the title screen.

signal cleared(improved: Dictionary)  ## The goal was reached and the clear recorded. `improved` is SaveGame.record_clear()'s result.

const RESULTS_MIN_TIME := 1.5  ## Seconds the results show before a button press can skip them.

@export var title: String = ""  ## Name shown as the stage starts and on its results, such as "Act 1: Sunny Beachfront".
@export_file("*.tscn") var hub_scene: String = ""  ## The world map, where the goal and a game over lead while a save slot is being played.
@export_file("*.tscn") var next_scene: String = ""  ## Where the goal leads with no save slot, as when testing. Empty goes to the title screen.

var improved: Dictionary = {}  ## What the last clear improved on the save slot (SaveGame.record_clear()).

var _ending := false
var _results_shown := -1.0  # Seconds the results have shown, or -1 before the goal.
var _moving_on := false


func _enter_tree() -> void:
	# Before the children are ready, so the player can ask GameState where to start.
	GameState.enter_stage(scene_file_path)
	Engine.time_scale = GameSettings.game_speed


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		(node as Player).died.connect(_on_player_died)
	GameState.stage_cleared.connect(_on_stage_cleared)


func _exit_tree() -> void:
	GameState.stop_clock()
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _results_shown >= 0.0:
		_results_shown += delta / maxf(Engine.time_scale, 0.01)


func _unhandled_input(event: InputEvent) -> void:
	# Skip the rest of the results.
	if _results_shown >= RESULTS_MIN_TIME and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_move_on()


## Whether the game can be paused now: not once the goal is reached or the game is over.
func can_pause() -> bool:
	return not _ending


## Back to the world map (or the title screen with no save slot), saving the slot on the way.
func quit_to_menu() -> void:
	get_tree().paused = false
	SaveGame.save()
	_to_menu()


## Starts again from the last checkpoint touched, as after a death but without losing a life.
func restart_from_checkpoint() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Starts the stage over from the beginning.
func restart_stage() -> void:
	get_tree().paused = false
	GameState.reset_stage()
	get_tree().reload_current_scene()


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
	var assisted := GameSettings.assist or GameSettings.game_speed < 1.0
	improved = SaveGame.record_clear(scene_file_path, GameState.time, GameState.cleared_rings, GameState.hidden_found_ids(), assisted)
	_results_shown = 0.0
	cleared.emit(improved)
	get_tree().create_timer(GameState.rules.results_time).timeout.connect(_move_on)


func _restart() -> void:
	get_tree().reload_current_scene()


func _game_over() -> void:
	GameState.end_game()
	get_tree().create_timer(GameState.rules.game_over_time).timeout.connect(_end_game)


func _end_game() -> void:
	GameState.new_game()
	_to_menu()


func _move_on() -> void:
	if _moving_on:
		return
	_moving_on = true
	if SaveGame.has_slot() and hub_scene != "":
		get_tree().change_scene_to_file(hub_scene)
	elif next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	else:
		_to_title()


func _to_menu() -> void:
	if SaveGame.has_slot() and hub_scene != "":
		get_tree().change_scene_to_file(hub_scene)
	else:
		_to_title()


func _to_title() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	get_tree().change_scene_to_file(main_scene)
