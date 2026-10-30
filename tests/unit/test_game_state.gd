extends "res://tests/test_suite.gd"
## Lives, checkpoints, the stage clock and found items, as kept by engine/systems/game_state.gd
## (the GameState autoload). Each test uses its own instance, outside the scene tree.

const GameStateScript := preload("res://engine/systems/game_state.gd")
const SPAWN := Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0))

var _game: GameStateScript


func before_each() -> void:
	_game = GameStateScript.new()
	_game.new_game()


func after_each() -> void:
	_game.free()


func test_a_new_game_starts_with_5_lives() -> void:
	assert_eq(_game.lives, 5)


func test_entering_a_stage_starts_its_clock_from_zero() -> void:
	_game.enter_stage("res://a.tscn")
	assert_almost_eq(_game.time, 0.0)
	assert_true(_game.clock_running)
	assert_eq(_game.spawn_point("res://a.tscn", Transform3D.IDENTITY), Transform3D.IDENTITY, "no checkpoint yet")


func test_a_restart_resumes_from_the_last_checkpoint() -> void:
	_game.enter_stage("res://a.tscn")
	_game.time = 42.0
	assert_true(_game.touch_checkpoint("Checkpoint", SPAWN))
	assert_true(_game.find("RedRing1", true))
	_game.time = 60.0
	_game.enter_stage("res://a.tscn")  # Reloaded after a death.
	assert_almost_eq(_game.time, 42.0, 1e-6, "clock back to the checkpoint's time")
	assert_eq(_game.spawn_point("res://a.tscn", Transform3D.IDENTITY), SPAWN)
	assert_true(_game.checkpoint_touched("Checkpoint"))
	assert_true(_game.is_found("RedRing1"), "finds kept")
	assert_eq(_game.hidden_found, 1)


func test_a_checkpoint_only_counts_the_first_time() -> void:
	_game.enter_stage("res://a.tscn")
	_game.time = 10.0
	_game.touch_checkpoint("Checkpoint", SPAWN)
	_game.time = 20.0
	assert_false(_game.touch_checkpoint("Checkpoint", Transform3D.IDENTITY))
	assert_almost_eq(_game.checkpoint_time, 10.0)
	assert_eq(_game.checkpoint_spawn, SPAWN)


func test_a_different_stage_starts_fresh() -> void:
	_game.enter_stage("res://a.tscn")
	_game.touch_checkpoint("Checkpoint", SPAWN)
	_game.find("RedRing1", true)
	_game.enter_stage("res://b.tscn")
	assert_eq(_game.checkpoint, "")
	assert_false(_game.is_found("RedRing1"))
	assert_eq(_game.hidden_found, 0)
	assert_eq(_game.spawn_point("res://b.tscn", Transform3D.IDENTITY), Transform3D.IDENTITY)


func test_a_checkpoint_only_applies_to_its_own_stage() -> void:
	_game.enter_stage("res://a.tscn")
	_game.touch_checkpoint("Checkpoint", SPAWN)
	assert_eq(_game.spawn_point("res://other.tscn", Transform3D.IDENTITY), Transform3D.IDENTITY)


func test_items_are_only_found_once() -> void:
	assert_true(_game.find("RedRing1", true))
	assert_false(_game.find("RedRing1", true))
	assert_true(_game.find("ExtraLife", false))
	assert_eq(_game.hidden_found, 1, "only hidden collectibles count toward the HUD total")


func test_losing_the_last_life_ends_the_game() -> void:
	_game.lives = 2
	assert_true(_game.lose_life(), "one left")
	assert_false(_game.lose_life(), "none left")
	assert_eq(_game.lives, 0)
	assert_false(_game.lose_life(), "never below zero")
	assert_eq(_game.lives, 0)


func test_a_new_game_clears_all_progress() -> void:
	_game.enter_stage("res://a.tscn")
	_game.touch_checkpoint("Checkpoint", SPAWN)
	_game.find("RedRing1", true)
	_game.lives = 1
	_game.new_game()
	assert_eq(_game.lives, 5)
	assert_eq(_game.stage, "")
	assert_eq(_game.checkpoint, "")
	assert_false(_game.is_found("RedRing1"))


func test_times_show_minutes_seconds_and_hundredths() -> void:
	assert_eq(_game.format_time(0.0), "0:00.00")
	assert_eq(_game.format_time(65.32), "1:05.32")
	assert_eq(_game.format_time(59.999), "0:59.99")
