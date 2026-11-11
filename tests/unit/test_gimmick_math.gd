extends "res://tests/test_suite.gd"
## Spring launches, bounces and tidal waves (engine/gimmicks/gimmick_math.gd), where a homing
## attack aims at a spring, where a RingLine puts its rings, and how a loop's curbs rise.

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


func test_a_homing_attack_aims_at_a_springs_axis_just_above_its_pad() -> void:
	# Springs play sounds through the Sfx autoload, so the scene is read rather than run.
	var state := (load("res://engine/gimmicks/spring.tscn") as PackedScene).get_state()
	var target := _saved(state, &"HomingTarget")
	assert_true(target.has("transform"), "spring.tscn has a HomingTarget")
	if not target.has("transform"):
		return
	assert_true(target.get("unique_name_in_owner", false), "the spring finds it as %HomingTarget")
	assert_eq((target["script"] as Script).resource_path, "res://engine/enemies/base/homing_target.gd")
	var at := (target["transform"] as Transform3D).origin
	assert_true(is_zero_approx(at.x) and is_zero_approx(at.z), "on the spring's axis: %s" % at)
	var pad := _saved(state, &"Pad")
	var catch_box := _saved(state, &"Shape")
	var pad_top := (pad["transform"] as Transform3D).origin.y + (pad["mesh"] as CylinderMesh).height * 0.5
	var box_top := (catch_box["transform"] as Transform3D).origin.y + (catch_box["shape"] as BoxShape3D).size.y * 0.5
	assert_true(at.y > pad_top and at.y < box_top, "above the pad (%.2f m), inside the catch box (to %.2f m): %.2f m" % [pad_top, box_top, at.y])


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


func test_a_tide_waits_low_rises_waits_high_and_falls() -> void:
	assert_almost_eq(GimmickMath.tide_level(5.0, 10.0, 6.0, 8.0, 6.0), 0.0, 1e-6, "low")
	assert_almost_eq(GimmickMath.tide_level(13.0, 10.0, 6.0, 8.0, 6.0), 0.5, 1e-6, "halfway up")
	assert_almost_eq(GimmickMath.tide_level(20.0, 10.0, 6.0, 8.0, 6.0), 1.0, 1e-6, "high")
	assert_almost_eq(GimmickMath.tide_level(27.0, 10.0, 6.0, 8.0, 6.0), 0.5, 1e-6, "halfway down")
	assert_almost_eq(GimmickMath.tide_level(35.0, 10.0, 6.0, 8.0, 6.0), 0.0, 1e-6, "low again, the next cycle")
	assert_true(GimmickMath.tide_level(11.0, 10.0, 6.0, 8.0, 6.0) < 1.0 / 6.0, "eases into the rise")


func test_a_platform_travels_out_waits_and_comes_back() -> void:
	assert_almost_eq(GimmickMath.platform_travel(0.0, 3.0, 1.0), 0.0, 1e-6, "at the start")
	assert_almost_eq(GimmickMath.platform_travel(1.5, 3.0, 1.0), 0.5, 1e-6, "halfway out")
	assert_almost_eq(GimmickMath.platform_travel(3.5, 3.0, 1.0), 1.0, 1e-6, "waiting at the far end")
	assert_almost_eq(GimmickMath.platform_travel(5.5, 3.0, 1.0), 0.5, 1e-6, "halfway back")
	assert_almost_eq(GimmickMath.platform_travel(7.5, 3.0, 1.0), 0.0, 1e-6, "waiting at the start")
	assert_almost_eq(GimmickMath.platform_travel(9.5, 3.0, 1.0), 0.5, 1e-6, "and again")


func test_only_a_fast_enough_approach_breaks_a_wall() -> void:
	assert_true(GimmickMath.breaks_wall(Vector3(0.0, 0.0, -10.0), Vector3.FORWARD, 3.0), "rolling into it")
	assert_false(GimmickMath.breaks_wall(Vector3(0.0, 0.0, -2.0), Vector3.FORWARD, 3.0), "too slow")
	assert_false(GimmickMath.breaks_wall(Vector3(10.0, 0.0, 0.0), Vector3.FORWARD, 3.0), "passing along it")
	assert_false(GimmickMath.breaks_wall(Vector3(0.0, 0.0, 10.0), Vector3.FORWARD, 3.0), "going away")



func test_a_leap_through_the_goal_ring_tops_out_at_the_ring() -> void:
	var gravity := 24.6
	var rise := GimmickMath.time_to_rise(0.9, gravity)
	assert_almost_eq(0.5 * gravity * rise * rise, 0.9, 1e-4, "rises 0.9 m in that time")
	for speed: float in [6.0, 15.0, 30.0]:
		var distance := speed * rise  # Where the leap starts.
		var up := GimmickMath.leap_speed(distance, speed, gravity)
		var time := distance / speed  # Time to reach the ring.
		assert_almost_eq(up - gravity * time, 0.0, 1e-4, "at %.0f m/s it's at the top as it reaches the ring" % speed)
		assert_almost_eq(up * time - 0.5 * gravity * time * time, 0.9, 1e-3, "at %.0f m/s, 0.9 m up" % speed)
	assert_almost_eq(GimmickMath.leap_speed(2.0, 0.0, gravity), 0.0, 1e-6, "standing still: no leap")

# The properties saved on the node named `node_name` in a scene, by name, without instancing it.
func _saved(state: SceneState, node_name: StringName) -> Dictionary:
	var found := {}
	for node in state.get_node_count():
		if state.get_node_name(node) != node_name:
			continue
		for i in state.get_node_property_count(node):
			found[String(state.get_node_property_name(node, i))] = state.get_node_property_value(node, i)
	return found
