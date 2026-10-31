extends Node
## What outlives a stage restart: lives, the stage clock, the checkpoints touched and the unique
## items found on this visit to the stage. Autoloaded as GameState. A Stage reports itself as it
## loads; after a death it reloads and resumes from the last checkpoint touched.

signal game_over  ## The last life was lost. The world map (or the title screen) returns after rules.game_over_time.
signal stage_cleared  ## The goal was reached. The results show for rules.results_time.

@export var rules: GameRules = preload("res://engine/systems/game_rules.tres")

var lives := 0
var time := 0.0  ## Seconds on the stage clock. It stops while the player is dead.
var clock_running := false
var stage := ""  ## Scene path of the stage being played, or "" before one starts.
var checkpoint := ""  ## The last checkpoint touched, as an id from id_of(), or "".
var checkpoint_spawn := Transform3D.IDENTITY  ## Where the player restarts from that checkpoint.
var checkpoint_time := 0.0  ## The stage clock when that checkpoint was touched.
var hidden_total := 0  ## Hidden collectibles in the current stage. Each one counts itself in as it loads.
var hidden_found := 0  ## Hidden collectibles found on this visit to the stage.
var cleared := false  ## The current stage's goal was reached.
var cleared_rings := 0  ## Rings the player had at the goal.

var _touched: Dictionary[String, bool] = {}  # Checkpoints touched on this visit to the stage.
var _found: Dictionary[String, bool] = {}  # Unique items (hidden collectibles, extra lives) found on this visit.
var _found_hidden: PackedStringArray = []  # The hidden collectibles among them.


func _ready() -> void:
	new_game()
	DebugOverlay.watch("Game", _describe)


func _physics_process(delta: float) -> void:
	if clock_running:
		time += delta


## Starts a fresh game: full lives and no stage in progress.
func new_game() -> void:
	lives = rules.start_lives
	stage = ""
	_clear_stage()


## Called by a Stage as it enters the tree. A different stage starts fresh; the same one again
## (reloaded after a death) resumes from its last checkpoint and keeps what was found.
func enter_stage(path: String) -> void:
	if path != stage:
		stage = path
		_clear_stage()
	time = checkpoint_time
	hidden_total = 0
	cleared = false
	clock_running = true


func stop_clock() -> void:
	clock_running = false


## Where a player in the stage at `stage_path` starts: the last checkpoint touched there, or
## `default` (its place in the scene).
func spawn_point(stage_path: String, default: Transform3D) -> Transform3D:
	return checkpoint_spawn if checkpoint != "" and stage_path == stage else default


## Records a checkpoint and the stage clock. Returns false if it was already touched on this visit.
func touch_checkpoint(id: String, spawn: Transform3D) -> bool:
	if _touched.has(id):
		return false
	_touched[id] = true
	checkpoint = id
	checkpoint_spawn = spawn
	checkpoint_time = time
	return true


func checkpoint_touched(id: String) -> bool:
	return _touched.has(id)


## Remembers a unique item as found. Returns false if it already was.
func find(id: String, hidden: bool) -> bool:
	if _found.has(id):
		return false
	_found[id] = true
	if hidden:
		hidden_found += 1
		_found_hidden.append(id)
	return true


func is_found(id: String) -> bool:
	return _found.has(id)


## Ids of the hidden collectibles found on this visit to the stage.
func hidden_found_ids() -> PackedStringArray:
	return _found_hidden.duplicate()


## Starts the current stage over: no checkpoints, nothing found, the clock back to zero.
func reset_stage() -> void:
	_clear_stage()


## Forgets the stage being played, so the next one entered starts fresh even if it is the same one.
func leave_stage() -> void:
	stage = ""
	_clear_stage()


func add_life() -> void:
	lives += 1


## Takes a life for a death. Returns whether any are left to carry on with.
func lose_life() -> bool:
	lives = maxi(lives - 1, 0)
	return lives > 0


## Announces the end of the game, after the last life is lost.
func end_game() -> void:
	clock_running = false
	game_over.emit()


## Ends the stage at its goal: stops the clock and announces the results. Only the first call counts.
func clear_stage(rings: int) -> void:
	if cleared:
		return
	cleared = true
	cleared_rings = rings
	clock_running = false
	stage_cleared.emit()


## A name for a node that stays the same when its stage reloads: its path from the stage root.
func id_of(node: Node) -> String:
	return str(node.owner.get_path_to(node)) if node.owner else str(node.get_path())


## Minutes, seconds and hundredths, as in 1:05.32.
func format_time(seconds: float) -> String:
	var hundredths := floori(seconds * 100.0 + 0.001)  # The nudge keeps 65.32 from showing as 1:05.31.
	return "%d:%02d.%02d" % [floori(hundredths / 6000.0), floori(hundredths / 100.0) % 60, hundredths % 100]


func _clear_stage() -> void:
	checkpoint = ""
	checkpoint_spawn = Transform3D.IDENTITY
	checkpoint_time = 0.0
	time = 0.0
	clock_running = false
	hidden_total = 0
	hidden_found = 0
	cleared = false
	cleared_rings = 0
	_touched.clear()
	_found.clear()
	_found_hidden.clear()


func _describe() -> String:
	return "lives %d  |  time %s%s  |  checkpoint %s" % [
		lives, format_time(time), "" if clock_running else " (stopped)", checkpoint if checkpoint != "" else "none",
	]
