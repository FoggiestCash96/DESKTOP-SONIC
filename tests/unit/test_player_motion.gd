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


func test_downhill_pull_follows_the_slope() -> void:
	assert_almost_eq(PlayerMotion.downhill(Vector3.UP).length(), 0.0, 1e-6, "none on flat ground")
	var slope := _slope_normal(30.0)
	var pull := PlayerMotion.downhill(slope)
	assert_almost_eq(pull.length(), 0.5, 1e-6, "sin 30° on a 30° slope")
	assert_almost_eq(pull.dot(slope), 0.0, 1e-6, "runs along the surface")
	assert_true(pull.y < 0.0 and pull.z > 0.0, "points down the slope")
	assert_almost_eq(PlayerMotion.downhill(Vector3.BACK).length(), 1.0, 1e-6, "full strength on a wall")
	assert_almost_eq(PlayerMotion.downhill(Vector3.DOWN).length(), 0.0, 1e-6, "none on a ceiling")


func test_standing_still_holds_on_gentle_slopes_only() -> void:
	# Friction (5.27 m/s²) beats the slope pull (14.06 m/s² × sin) below about 22°.
	assert_false(PlayerMotion.slope_beats_friction(_slope_normal(15.0), physics), "15° holds")
	assert_true(PlayerMotion.slope_beats_friction(_slope_normal(30.0), physics), "30° slides")


func test_slow_players_slip_on_steep_surfaces() -> void:
	var slow := physics.slip_threshold - 0.1
	assert_true(PlayerMotion.slips(slow, _slope_normal(60.0), physics), "slow on 60°")
	assert_false(PlayerMotion.slips(slow, _slope_normal(30.0), physics), "slow on 30°")
	assert_false(PlayerMotion.slips(physics.slip_threshold + 0.1, _slope_normal(60.0), physics), "fast on 60°")


func test_only_overhangs_drop_a_slow_player() -> void:
	var slow := physics.slip_threshold * 0.9
	assert_true(PlayerMotion.falls_off(slow, Vector3.DOWN, physics), "slow on a ceiling")
	assert_false(PlayerMotion.falls_off(physics.slip_threshold, Vector3.DOWN, physics), "classic slip speed holds upside down")
	assert_false(PlayerMotion.falls_off(0.0, Vector3.BACK, physics), "walls don't drop the player, they slip")
	physics.ground_magnetism = physics.grv * 0.75
	assert_false(PlayerMotion.falls_off(physics.slip_threshold * 0.5, Vector3.DOWN, physics), "magnetism holds at half speed")


func test_landing_keeps_the_velocity_along_the_surface() -> void:
	var landed := PlayerMotion.along_surface(Vector3(3.0, -10.0, 0.0), Vector3.UP)
	assert_eq(landed, Vector3(3.0, 0.0, 0.0), "flat ground keeps the horizontal part")
	var on_slope := PlayerMotion.along_surface(Vector3(0.0, -10.0, 0.0), _slope_normal(30.0))
	assert_almost_eq(on_slope.length(), 5.0, 1e-5, "a straight drop onto 30° keeps sin 30° of the speed")


func test_rolling_coasts_twice_as_far_as_running() -> void:
	# Classic: roll friction is half of running friction, so stopping from top speed takes twice as long.
	var speed := physics.top
	var ticks := 0
	while speed > 0.0 and ticks < 2000:
		speed = PlayerMotion.roll_speed(speed, false, physics, TICK)
		ticks += 1
	assert_almost_eq(ticks * TICK, 256.0 / 60.0, TICK * 1.5, "time to stop rolling")
	var braked := PlayerMotion.roll_speed(physics.top, true, physics, 0.1)
	assert_almost_eq(braked, physics.top - (physics.roll_frc + physics.roll_dec) * 0.1, 1e-5, "braking adds roll_dec")
	assert_almost_eq(PlayerMotion.roll_speed(1.0, true, physics, 1.0), 0.0, 1e-6, "braking stops at zero, it doesn't reverse")


func test_spin_dash_launch_speed_matches_the_classic_formula() -> void:
	assert_almost_eq(PlayerMotion.spin_dash_speed(0.0, physics), 15.0, 1e-6, "no charge: 8 px/frame")
	assert_almost_eq(PlayerMotion.spin_dash_speed(8.0, physics), 22.5, 1e-6, "full charge: 12 px/frame")
	assert_almost_eq(PlayerMotion.spin_dash_speed(3.9, physics), 15.0 + 3.0 * 0.9375, 1e-6, "only whole charge counts")


func test_spin_dash_charge_bleeds_off_at_the_classic_rate() -> void:
	var one_frame := PlayerMotion.decay_charge(8.0, 1.0 / 60.0)
	assert_almost_eq(one_frame, 8.0 * 31.0 / 32.0, 1e-5, "1/32 per classic frame")
	var two_ticks := PlayerMotion.decay_charge(PlayerMotion.decay_charge(8.0, TICK), TICK)
	assert_almost_eq(two_ticks, one_frame, 1e-5, "same at 120 Hz")


func test_damage_and_ring_loss_defaults_are_classic() -> void:
	assert_almost_eq(physics.invulnerable_time, 2.0, 1e-6, "120 frames of flashing")
	assert_almost_eq(physics.lost_ring_pickup_delay, 64.0 / 60.0, 1e-6, "64 frames before scattered rings can be grabbed")
	assert_almost_eq(physics.lost_ring_lifetime, 256.0 / 60.0, 1e-6, "256 frames before they vanish")
	assert_almost_eq(physics.lost_ring_gravity, 10.546875, 1e-6, "0.09375 px/frame² on scattered rings")
	assert_eq(physics.max_lost_rings, 32)


func test_a_hit_knocks_the_player_back_and_up_at_the_classic_speeds() -> void:
	var knockback := PlayerMotion.hurt_velocity(Vector3.BACK, physics)
	assert_almost_eq(knockback.z, 3.75, 1e-5, "2 px/frame away")
	assert_almost_eq(knockback.y, 7.5, 1e-5, "4 px/frame up")
	assert_almost_eq(knockback.x, 0.0, 1e-5)


func test_a_hit_scatters_at_most_32_rings() -> void:
	assert_eq(PlayerMotion.ring_scatter(50, physics).size(), 32)
	assert_eq(PlayerMotion.ring_scatter(7, physics).size(), 7)
	assert_eq(PlayerMotion.ring_scatter(0, physics).size(), 0)


func test_the_first_16_scattered_rings_fly_fast_and_the_rest_slow() -> void:
	var velocities := PlayerMotion.ring_scatter(32, physics)
	for i in velocities.size():
		var expected := 7.5 if i < 16 else 3.75
		assert_almost_eq(velocities[i].length(), expected, 1e-4, "ring %d" % i)
		assert_true(velocities[i].y > 0.0, "ring %d flies upward" % i)


func test_scattered_rings_fan_out_evenly_all_around() -> void:
	var sideways := Vector3.ZERO
	for velocity in PlayerMotion.ring_scatter(16, physics):
		sideways += Vector3(velocity.x, 0.0, velocity.z)
	assert_almost_eq(sideways.length(), 0.0, 1e-4, "no direction is favoured")


func test_the_model_pose_follows_the_players_situation() -> void:
	# pose(dead, hurt, curled, grounded, sprung, finished, braking, pushing)
	assert_eq(PlayerMotion.pose(false, false, false, true, false, false, false, false), &"ground", "running or standing")
	assert_eq(PlayerMotion.pose(false, false, true, true, false, false, false, false), &"ball", "rolling")
	assert_eq(PlayerMotion.pose(false, false, true, false, false, false, false, false), &"ball", "jumping")
	assert_eq(PlayerMotion.pose(false, false, false, false, true, false, false, false), &"spring", "rising from a spring")
	assert_eq(PlayerMotion.pose(false, false, false, false, false, false, false, false), &"fall", "falling uncurled")
	assert_eq(PlayerMotion.pose(false, false, false, true, false, false, true, false), &"skid", "braking")
	assert_eq(PlayerMotion.pose(false, false, false, true, false, false, false, true), &"push", "pushing a wall")
	assert_eq(PlayerMotion.pose(false, false, false, true, false, true, false, false), &"victory", "stopped after the goal")


func test_being_hit_or_dying_outranks_everything_else() -> void:
	assert_eq(PlayerMotion.pose(false, true, true, false, true, false, true, true), &"hurt")
	assert_eq(PlayerMotion.pose(true, true, true, false, true, true, true, true), &"death")


func test_the_run_cycle_only_speeds_up_beyond_the_max_run() -> void:
	assert_almost_eq(CharacterModel.run_cycle_rate(10.0), 1.0, 1e-6, "normal rate at running speed")
	assert_almost_eq(CharacterModel.run_cycle_rate(18.0), 1.0, 1e-6, "normal at the max run's speed")
	assert_almost_eq(CharacterModel.run_cycle_rate(27.0), 1.5, 1e-6, "half again as fast at 27 m/s")


func test_a_push_speeds_the_player_up_but_only_to_its_own_speed() -> void:
	var pushed := PlayerMotion.pushed(Vector3(0.0, 0.0, -10.0), Vector3.FORWARD, 17.0, 2.0)
	assert_true(pushed.is_equal_approx(Vector3(0.0, 0.0, -12.0)), "carried faster: %s" % pushed)
	pushed = PlayerMotion.pushed(Vector3(0.0, 0.0, -16.5), Vector3.FORWARD, 17.0, 2.0)
	assert_true(pushed.is_equal_approx(Vector3(0.0, 0.0, -17.0)), "but no faster than the water: %s" % pushed)
	pushed = PlayerMotion.pushed(Vector3(0.0, 0.0, -20.0), Vector3.FORWARD, 17.0, 2.0)
	assert_true(pushed.is_equal_approx(Vector3(0.0, 0.0, -20.0)), "a faster player is left alone: %s" % pushed)


func test_a_push_against_the_player_slows_them_down() -> void:
	var pushed := PlayerMotion.pushed(Vector3(0.0, 0.0, -10.0), Vector3.BACK, 6.0, 1.0)
	assert_true(pushed.is_equal_approx(Vector3(0.0, 0.0, -9.0)), str(pushed))


func test_speed_shoes_double_the_classic_values() -> void:
	var fast := PlayerMotion.with_speed_shoes(physics)
	assert_almost_eq(fast.top, 22.5, 1e-5, "12 px/frame")
	assert_almost_eq(fast.acc, 10.546875, 1e-5, "0.09375 px/frame²")
	assert_almost_eq(fast.frc, 10.546875, 1e-5)
	assert_almost_eq(fast.air_acc, 21.09375, 1e-5, "0.1875 px/frame²")
	assert_almost_eq(fast.roll_frc, 5.2734375, 1e-5, "0.046875 px/frame²")
	assert_almost_eq(fast.dec, physics.dec, 1e-6, "braking is unchanged")
	assert_almost_eq(physics.top, 11.25, 1e-6, "the original values are untouched")



func test_homing_reaches_targets_ahead_within_range() -> void:
	var ahead := Vector3.FORWARD
	assert_true(PlayerMotion.in_homing_reach(Vector3(0.0, -2.0, -8.0), ahead, 12.0, 90.0), "ahead and below")
	assert_true(PlayerMotion.in_homing_reach(Vector3(-7.0, 1.0, -7.2), ahead, 12.0, 90.0), "just inside 45° to the side")
	assert_false(PlayerMotion.in_homing_reach(Vector3(-7.2, 0.0, -7.0), ahead, 12.0, 90.0), "just outside 45° to the side")
	assert_false(PlayerMotion.in_homing_reach(Vector3(0.0, 0.0, -12.5), ahead, 12.0, 90.0), "too far")
	assert_false(PlayerMotion.in_homing_reach(Vector3(0.0, 0.0, 4.0), ahead, 12.0, 90.0), "behind")
	assert_true(PlayerMotion.in_homing_reach(Vector3(0.3, -5.0, 0.4), ahead, 12.0, 90.0), "straight below counts as in front")


func test_air_dash_sets_a_minimum_speed_ahead() -> void:
	var slow := PlayerMotion.air_dash(Vector3(1.0, 0.0, -3.0), Vector3.FORWARD, physics.air_dash_speed)
	assert_true(slow.is_equal_approx(Vector3(0.0, 0.0, -physics.air_dash_speed)), "speeds up to the dash speed and drops the drift: %s" % slow)
	var fast := PlayerMotion.air_dash(Vector3(0.0, 0.0, -25.0), Vector3.FORWARD, physics.air_dash_speed)
	assert_true(fast.is_equal_approx(Vector3(0.0, 0.0, -25.0)), "a faster player keeps their speed: %s" % fast)


func test_destroying_an_enemy_rebounds_as_in_the_classic_games() -> void:
	var slowdown := physics.rebound_slowdown
	assert_almost_eq(slowdown, 1.875, 1e-6, "1 px/frame")
	assert_almost_eq(PlayerMotion.enemy_rebound(-6.0, 2.0, 1.0, slowdown), 6.0, 1e-6, "falling onto it from above bounces back up")
	assert_almost_eq(PlayerMotion.enemy_rebound(-6.0, 0.5, 1.0, slowdown), -4.125, 1e-6, "falling past it from below only slows the fall")
	assert_almost_eq(PlayerMotion.enemy_rebound(8.0, 0.5, 1.0, slowdown), 6.125, 1e-6, "rising through it only slows the rise")

## Normal of a slope that rises toward -Z at `degrees` from flat.
func _slope_normal(degrees: float) -> Vector3:
	return Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(degrees))


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
