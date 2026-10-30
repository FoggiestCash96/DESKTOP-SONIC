extends "res://tests/test_suite.gd"
## Movement math in engine/player/player_motion.gd, checked against the classic 60 fps values
## (Sonic Physics Guide) and for giving the same results at any tick rate.

const TICK := 1.0 / 120.0

var physics: PlayerPhysics


func before_each() -> void:
	physics = PlayerPhysics.new()


func test_classic_values_convert_to_si_units() -> void:
	assert_almost_eq(6.0 * PlayerPhysics.SPEED, 11.25, 1e-6, "6 px/frame")
	assert_almost_eq(0.046875 * PlayerPhysics.ACCEL, 5.2734375, 1e-6, "0.046875 px/frame²")
	assert_almost_eq(physics.top, 11.25, 1e-6, "default top speed")
	assert_almost_eq(physics.grv, 24.609375, 1e-6, "default gravity")


func test_reaches_top_speed_in_the_classic_time() -> void:
	# Classic: 6 / 0.046875 = 128 frames at 60 fps.
	var speed := 0.0
	var ticks := 0
	while speed < physics.top and ticks < 1000:
		speed = PlayerMotion.run_speed(speed, 1.0, physics, TICK)
		ticks += 1
	assert_almost_eq(ticks * TICK, 128.0 / 60.0, TICK * 1.5, "time to top speed")
	for _i in 120:
		speed = PlayerMotion.run_speed(speed, 1.0, physics, TICK)
	assert_almost_eq(speed, physics.top, 1e-6, "running alone never passes top speed")


func test_running_gives_the_same_speed_at_any_tick_rate() -> void:
	var at_60 := 0.0
	var at_120 := 0.0
	for _i in 60:
		at_60 = PlayerMotion.run_speed(at_60, 1.0, physics, 1.0 / 60.0)
	for _i in 120:
		at_120 = PlayerMotion.run_speed(at_120, 1.0, physics, 1.0 / 120.0)
	assert_almost_eq(at_60, at_120, 1e-4)
	assert_almost_eq(at_120, physics.acc, 1e-4, "one second of acceleration")


func test_full_input_keeps_momentum_above_top_speed() -> void:
	assert_almost_eq(PlayerMotion.run_speed(20.0, 1.0, physics, TICK), 20.0, 1e-6)


func test_partial_input_eases_down_to_a_slower_target() -> void:
	var speed := physics.top
	for _i in 600:
		speed = PlayerMotion.run_speed(speed, 0.5, physics, TICK)
	assert_almost_eq(speed, physics.top * 0.5, 1e-6)


func test_friction_stops_from_top_speed_in_the_classic_time() -> void:
	var speed := physics.top
	var ticks := 0
	while speed > 0.0 and ticks < 1000:
		speed = PlayerMotion.run_speed(speed, 0.0, physics, TICK)
		ticks += 1
	assert_almost_eq(ticks * TICK, 128.0 / 60.0, TICK * 1.5, "time to stop")


func test_braking_stops_then_turns_around() -> void:
	# Classic: 6 / 0.5 = 12 frames to stop, then 0.5 px/frame the other way.
	var speed := physics.top
	var ticks := 0
	while speed > 0.0 and ticks < 1000:
		speed = PlayerMotion.brake_speed(speed, physics, TICK)
		ticks += 1
	assert_almost_eq(ticks * TICK, 12.0 / 60.0, TICK * 1.5, "time to stop")
	assert_almost_eq(speed, -physics.turnaround_speed, 1e-6, "speed in the new direction")


func test_turn_rate_eases_from_low_to_high_speed() -> void:
	assert_almost_eq(rad_to_deg(PlayerMotion.turn_rate(0.0, physics)), 720.0, 1e-3, "standing")
	assert_almost_eq(rad_to_deg(PlayerMotion.turn_rate(physics.top * 0.5, physics)), 450.0, 1e-3, "half top speed")
	assert_almost_eq(rad_to_deg(PlayerMotion.turn_rate(physics.top, physics)), 180.0, 1e-3, "top speed")
	assert_almost_eq(rad_to_deg(PlayerMotion.turn_rate(physics.top * 2.0, physics)), 180.0, 1e-3, "above top speed")


func test_turning_is_limited_each_tick() -> void:
	var limit := deg_to_rad(10.0)
	var turned := PlayerMotion.turn_toward(Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, limit)
	assert_almost_eq(rad_to_deg(Vector3.FORWARD.angle_to(turned)), 10.0, 1e-3, "turns by the limit")
	assert_true(turned.dot(Vector3.RIGHT) > 0.0, "turns toward the input")
	var near := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(5.0))
	var reached := PlayerMotion.turn_toward(Vector3.FORWARD, near, Vector3.UP, limit)
	assert_almost_eq(rad_to_deg(Vector3.FORWARD.angle_to(reached)), 5.0, 1e-3, "reaches a close direction at once")


func test_full_jump_is_about_three_metres_high() -> void:
	assert_almost_eq(_jump_apex(true), 3.0, 0.1)


func test_letting_go_early_cuts_the_jump_short() -> void:
	# Capped to 7.5 m/s after the first tick: about 0.1 m + 7.3² / (2 × 24.6) m.
	assert_almost_eq(_jump_apex(false), 1.2, 0.1)


func test_falling_speed_is_capped() -> void:
	var vertical := 0.0
	for _i in 1200:
		vertical = PlayerMotion.fall_speed(vertical, physics, TICK)
	assert_almost_eq(vertical, -physics.max_fall, 1e-6)


func test_air_control_steers_without_draining_momentum() -> void:
	var steered := PlayerMotion.air_velocity(Vector3(0.0, 0.0, -20.0), Vector3.RIGHT, physics, TICK)
	assert_true(steered.x > 0.0, "steers toward the input")
	assert_almost_eq(steered.length(), 20.0, 1e-4, "keeps speed above top")
	var pushed := PlayerMotion.air_velocity(Vector3(0.0, 0.0, -physics.top), Vector3.FORWARD, physics, TICK)
	assert_almost_eq(pushed.length(), physics.top, 1e-4, "pushing cannot pass top speed")
	var from_rest := PlayerMotion.air_velocity(Vector3.ZERO, Vector3.FORWARD, physics, 1.0)
	assert_almost_eq(from_rest.length(), physics.air_acc, 1e-4, "accelerates at air_acc")


func test_air_drag_matches_the_classic_rate_near_the_apex() -> void:
	# Classic: lose 1/32 of horizontal speed per 60 fps frame while rising slower than 4 px/frame.
	var horizontal := Vector3(physics.top, 0.0, 0.0)
	var one_frame := PlayerMotion.air_drag(horizontal, 1.0, 1.0 / 60.0)
	assert_almost_eq(one_frame.x, physics.top * 31.0 / 32.0, 1e-5, "one classic frame")
	var two_ticks := PlayerMotion.air_drag(PlayerMotion.air_drag(horizontal, 1.0, TICK), 1.0, TICK)
	assert_almost_eq(two_ticks.x, one_frame.x, 1e-5, "two 120 Hz ticks give the same result")
	assert_eq(PlayerMotion.air_drag(horizontal, 10.0, TICK), horizontal, "no drag while rising fast")
	assert_eq(PlayerMotion.air_drag(horizontal, -1.0, TICK), horizontal, "no drag while falling")


## Height of a jump simulated tick by tick the way the player does it: the jump tick moves at
## full jump speed, then each tick applies the release cap (if not held) and gravity.
func _jump_apex(hold_jump: bool) -> float:
	var vertical := physics.jmp
	var height := 0.0
	while vertical > 0.0:
		height += vertical * TICK
		if not hold_jump:
			vertical = PlayerMotion.release_cap(vertical, physics)
		vertical = PlayerMotion.fall_speed(vertical, physics, TICK)
	return height
