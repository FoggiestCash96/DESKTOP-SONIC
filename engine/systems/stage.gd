class_name Stage
extends Node3D
## Root script for a playable stage. It reports the stage to GameState, sets the game speed, restarts
## the stage from the last checkpoint after a player dies, and ends the game when the lives run out.
## At the goal it adds up the score and the rank it earns (`tally`), records the clear on the save
## slot (SaveGame), shows the results, and moves on: to the world map while a save slot is being
## played, otherwise to `next_scene` or the title screen. It plays its `music` (Music), fades it at a
## death, and plays the jingles at the goal and game over.
##
## In time attack (GameState.time_attack) no lives are lost: a death, or the restart button at any
## time, starts the act over. The run is recorded, the fastest one is kept as the slot's ghost, and
## that ghost runs alongside the player.

signal cleared(improved: Dictionary)  ## The goal was reached and the clear recorded. `improved` is what SaveGame.record_clear() (or, in time attack, record_time_attack()) returned.

const RESULTS_MIN_TIME := 1.5  ## Seconds the results show before a button press can skip them.

@export var title: String = ""  ## Name shown as the stage starts and on its results, such as "Act 1: Sunny Beachfront".
@export_file("*.tscn") var hub_scene: String = ""  ## The world map, where the goal and a game over lead while a save slot is being played.
@export_file("*.tscn") var next_scene: String = ""  ## Where the goal leads with no save slot, as when testing. Empty goes to the title screen.
@export var music: AudioStream  ## The stage's music. Empty plays none.
@export var fast_music: AudioStream  ## The same music faster, for speed shoes. Empty speeds `music` up instead.
@export var par_time: float = 0.0  ## Seconds a good run of the act takes. The goal's time bonus counts down to nothing at twice this (GameRules.time_bonus()); 0 gives none.
@export var rank_scores: PackedInt32Array = []  ## The lowest goal totals for ranks S, A, B and C, in that order; anything less is D. Empty gives no rank.

var improved: Dictionary = {}  ## What the last clear improved on the save slot (SaveGame.record_clear()).
var tally: Dictionary = {}  ## The goal's score (GameRules.tally()) and the rank it earned, as "rank". Empty before the goal and in time attack.

var _ending := false
var _results_shown := -1.0  # Seconds the results have shown, or -1 before the goal.
var _moving_on := false
var _runner: Player  # In time attack, the player whose run is recorded...
var _recording: GhostRun  # ...and the recording.


func _enter_tree() -> void:
	# Before the children are ready, so the player can ask GameState where to start.
	GameState.enter_stage(scene_file_path)
	Engine.time_scale = GameSettings.game_speed


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		(node as Player).died.connect(_on_player_died)
	GameState.stage_cleared.connect(_on_stage_cleared)
	Music.play(music, fast_music)
	if GameState.time_attack:
		_runner = get_tree().get_first_node_in_group(Player.GROUP) as Player
		_recording = GhostRun.new()
		_add_ghost()


func _exit_tree() -> void:
	GameState.stop_clock()
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _results_shown >= 0.0:
		_results_shown += delta / maxf(Engine.time_scale, 0.01)


func _physics_process(_delta: float) -> void:
	if _recording and is_instance_valid(_runner) and GameState.clock_running:
		_recording.add(GameState.time, _runner.model_transform(), _runner.pose(), _runner.pose_speed())


func _unhandled_input(event: InputEvent) -> void:
	if GameState.time_attack and not _moving_on and event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		restart_stage()
		return
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
	Music.stop(1.0)
	# Timers call back through signals, which are dropped if the stage is freed first (on pause).
	# In time attack nothing is lost: the act starts over.
	var next := restart_stage if GameState.time_attack else (_restart if GameState.lose_life() else _game_over)
	get_tree().create_timer(GameState.rules.restart_delay).timeout.connect(next)


func _on_stage_cleared() -> void:
	_ending = true
	var assisted := GameSettings.assist or GameSettings.game_speed < 1.0
	if GameState.time_attack:
		if _recording and is_instance_valid(_runner):
			_recording.add(GameState.time, _runner.model_transform(), _runner.pose(), _runner.pose_speed(), true)
		improved = SaveGame.record_time_attack(scene_file_path, GameState.time, GameState.splits, assisted)
		if bool(improved.get("best_time", false)) and _recording and not _recording.is_empty():
			SaveGame.save_ghost(scene_file_path, _recording.to_dict())
	else:
		tally = GameState.rules.tally(GameState.score, GameState.time, GameState.cleared_rings, par_time)
		tally["rank"] = GameState.rules.rank_of(int(tally["total"]), rank_scores)
		improved = SaveGame.record_clear(scene_file_path, GameState.time, GameState.cleared_rings, GameState.hidden_found_ids(), assisted, int(tally["total"]), str(tally["rank"]))
	_results_shown = 0.0
	Music.jingle(&"clear", false)
	cleared.emit(improved)
	get_tree().create_timer(GameState.rules.results_time).timeout.connect(_move_on)


func _restart() -> void:
	get_tree().reload_current_scene()


func _game_over() -> void:
	GameState.end_game()
	Music.jingle(&"game_over", false)
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


# In time attack, the ghost of the slot's fastest run of the act, if it has one.
func _add_ghost() -> void:
	if _runner == null or _runner.character == null or _runner.character.model == null or not SaveGame.act(scene_file_path).has("ta_time"):
		return
	var run := GhostRun.new()
	if not run.from_dict(SaveGame.load_ghost(scene_file_path)):
		return
	var ghost := PlayerGhost.new()
	ghost.name = "Ghost"
	ghost.setup(run, _runner.character.model)
	add_child(ghost)
