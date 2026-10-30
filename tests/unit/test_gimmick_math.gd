extends "res://tests/test_suite.gd"
## Spring launches, bounces and tidal waves (engine/gimmicks/gimmick_math.gd), where a RingLine
## puts its rings, and how a loop's curbs rise.

const YELLOW_SPRING := 18.75  ## The classic yellow spring, 10 px/frame.
const DIAGONAL := Vector3(0.0, 0.70710678, -0.70710678)  ## Up and along -Z, 45° each.


func test_an_upward_spring_keeps_the_running_speed() -> void:
	var launch := GimmickMath.spring_velocity(Vector3(5.0, -2.0, 0.0), Vector3.UP, YELLOW_SPRING, true)
	assert_almost_eq(launch.x, 5.0, 1e-5, "running speed kept")
	assert_almost_eq(launch.y, YELLOW_SPRING, 1e-5, "falling speed replaced by the launch")


func test_a_spring_without_momentum_launches_exactly_along_itself() -> void:
	var launch := GimmickMath.spring_velocity(Vector3(5.0, -2.0, 3.0), DIAGONAL, YELLOW_SPRING, false)
	assert_true(launch.is_equal_approx(DIAGONAL * YELLOW_SPRING), str(launch))


func test_a_diagonal_spring_with_momentum_keeps_only_the_speed_across_it() -> void:
	var before := Vector3(4.0, 0.0, -6.0)
	var launch := GimmickMath.spring_velocity(before, DIAGONAL, YELLOW_SPRING, true)
	assert_almost_eq(launch.dot(DIAGONAL), YELLOW_SPRING, 1e-4, "launch speed along the spring")
	var across_before := before - DIAGONAL * DIAGONAL.dot(before)
	var across_after := launch - DIAGONAL * DIAGONAL.dot(launch)
	assert_true(across_after.is_equal_approx(across_before), "speed across the spring kept")


func test_only_springs_lying_on_their_side_run_along_the_ground() -> void:
	assert_true(GimmickMath.runs_along(Vector3.BACK, Vector3.UP), "flat")
	assert_true(GimmickMath.runs_along(Vector3(0.0, 0.34, -0.94), Vector3.UP), "20° up")
	assert_false(GimmickMath.runs_along(DIAGONAL, Vector3.UP), "45° up")
	assert_false(GimmickMath.runs_along(Vector3.UP, Vector3.UP), "straight up")


func test_a_bounce_reverses_and_shrinks_the_speed_into_the_surface() -> void:
	var after := GimmickMath.bounce(Vector3(3.0, -4.0, 0.0), Vector3.UP, 0.75)
	assert_true(after.is_equal_approx(Vector3(3.0, 3.0, 0.0)), str(after))


func test_moving_away_from_a_surface_is_not_a_bounce() -> void:
	var after := GimmickMath.bounce(Vector3(3.0, 4.0, 0.0), Vector3.UP, 0.75)
	assert_true(after.is_equal_approx(Vector3(3.0, 4.0, 0.0)), str(after))


func test_a_ring_line_spaces_its_rings_along_minus_z() -> void:
	assert_true(RingLine.ring_position(0, 5, 1.5, 0.0).is_equal_approx(Vector3.ZERO))
	assert_true(RingLine.ring_position(4, 5, 1.5, 0.0).is_equal_approx(Vector3(0.0, 0.0, -6.0)))


func test_a_wave_surges_up_then_drains_back_then_rests() -> void:
	assert_true(GimmickMath.wave_cycle(0.0, 6.0, 4.0, 2.0).is_equal_approx(Vector2(0.0, 1.0)), "starts surging at the shore")
	assert_true(GimmickMath.wave_cycle(3.0, 6.0, 4.0, 2.0).is_equal_approx(Vector2(0.5, 1.0)), "halfway up")
	assert_true(GimmickMath.wave_cycle(8.0, 6.0, 4.0, 2.0).is_equal_approx(Vector2(0.5, -1.0)), "halfway back down")
	assert_true(GimmickMath.wave_cycle(11.0, 6.0, 4.0, 2.0).is_equal_approx(Vector2(0.0, 0.0)), "resting")
	assert_true(GimmickMath.wave_cycle(15.0, 6.0, 4.0, 2.0).is_equal_approx(Vector2(0.5, 1.0)), "the next wave, 12 s later")


func test_a_loops_curbs_rise_from_nothing_at_both_ends() -> void:
	assert_almost_eq(LoopTrack.curb_rise(0.0, 0.6), 0.0, 1e-6, "flush at the entry")
	assert_almost_eq(LoopTrack.curb_rise(LoopTrack.CURB_RAMP * 0.5, 0.6), 0.3, 1e-6, "halfway up the ramp")
	assert_almost_eq(LoopTrack.curb_rise(PI, 0.6), 0.6, 1e-6, "full height over the top")
	assert_almost_eq(LoopTrack.curb_rise(TAU, 0.6), 0.0, 1e-6, "flush at the exit")


func test_an_arched_ring_line_peaks_in_the_middle() -> void:
	assert_almost_eq(RingLine.ring_position(2, 5, 1.5, 2.0).y, 2.0, 1e-5, "middle ring at the full height")
	assert_almost_eq(RingLine.ring_position(0, 5, 1.5, 2.0).y, 0.0, 1e-5, "ends on the line")
	assert_almost_eq(RingLine.ring_position(4, 5, 1.5, 2.0).y, 0.0, 1e-5)
