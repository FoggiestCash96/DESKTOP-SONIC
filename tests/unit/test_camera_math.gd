extends "res://tests/test_suite.gd"
## Camera math in engine/camera/camera_math.gd.


func test_orbit_puts_the_camera_behind_and_above() -> void:
	var level := CameraMath.orbit_offset(0.0, 0.0, 6.0)
	assert_almost_eq(level.distance_to(Vector3(0.0, 0.0, 6.0)), 0.0, 1e-5, "yaw 0 sits on the +Z side")
	var raised := CameraMath.orbit_offset(0.0, deg_to_rad(-15.0), 6.0)
	assert_almost_eq(raised.y, 6.0 * sin(deg_to_rad(15.0)), 1e-5, "negative pitch raises the camera")
	assert_almost_eq(raised.length(), 6.0, 1e-5, "keeps its distance")
	var turned := CameraMath.orbit_offset(deg_to_rad(-90.0), 0.0, 6.0)
	assert_almost_eq(turned.distance_to(Vector3(-6.0, 0.0, 0.0)), 0.0, 1e-5, "yaw -90° sits on the -X side")


func test_yaw_and_forward_agree() -> void:
	for degrees: float in [0.0, 45.0, -90.0, 180.0]:
		var yaw := deg_to_rad(degrees)
		var forward := CameraMath.forward_for_yaw(yaw)
		assert_almost_eq(wrapf(CameraMath.yaw_facing(forward) - yaw, -PI, PI), 0.0, 1e-5, "%.0f°" % degrees)
	assert_almost_eq(CameraMath.forward_for_yaw(0.0).distance_to(Vector3.FORWARD), 0.0, 1e-5, "yaw 0 looks along -Z")
	var orbit := CameraMath.orbit_offset(0.7, 0.0, 1.0)
	assert_almost_eq(orbit.dot(CameraMath.forward_for_yaw(0.7)), -1.0, 1e-5, "the camera sits behind where it looks")


func test_approach_angle_takes_the_short_way_round() -> void:
	var from := deg_to_rad(170.0)
	var stepped := CameraMath.approach_angle(from, deg_to_rad(-170.0), deg_to_rad(5.0))
	assert_almost_eq(rad_to_deg(stepped), 175.0, 1e-4, "crosses 180° instead of going back round")
	var reached := CameraMath.approach_angle(0.0, deg_to_rad(3.0), deg_to_rad(5.0))
	assert_almost_eq(rad_to_deg(reached), 3.0, 1e-4, "stops at the target")


func test_field_of_view_widens_with_speed() -> void:
	assert_almost_eq(CameraMath.speed_fov(0.0, 11.25, 70.0, 85.0), 70.0, 1e-5, "standing")
	assert_almost_eq(CameraMath.speed_fov(5.625, 11.25, 70.0, 85.0), 77.5, 1e-5, "half top speed")
	assert_almost_eq(CameraMath.speed_fov(30.0, 11.25, 70.0, 85.0), 85.0, 1e-5, "capped above top speed")


func test_look_ahead_scales_with_velocity_up_to_a_limit() -> void:
	assert_almost_eq(CameraMath.look_ahead(Vector3(0.0, 0.0, -10.0), 0.3, 6.0).length(), 3.0, 1e-5, "0.3 s of 10 m/s")
	assert_almost_eq(CameraMath.look_ahead(Vector3(0.0, 0.0, -30.0), 0.3, 6.0).length(), 6.0, 1e-5, "capped at 6 m")


func test_smoothing_is_frame_rate_independent() -> void:
	assert_almost_eq(CameraMath.smoothing(0.5, 0.5), 1.0 - exp(-1.0), 1e-6, "63% per time constant")
	var two_steps := 1.0 - pow(1.0 - CameraMath.smoothing(0.5, 0.25), 2.0)
	assert_almost_eq(two_steps, CameraMath.smoothing(0.5, 0.5), 1e-6, "two half steps make one whole")
	assert_almost_eq(CameraMath.smoothing(0.0, 0.016), 1.0, 1e-6, "no smoothing")


func test_blend_weight_eases_in_and_out() -> void:
	assert_almost_eq(CameraMath.blend_weight(0.0, 0.6), 0.0, 1e-6, "start")
	assert_almost_eq(CameraMath.blend_weight(0.3, 0.6), 0.5, 1e-6, "halfway")
	assert_almost_eq(CameraMath.blend_weight(0.9, 0.6), 1.0, 1e-6, "done")
	assert_true(CameraMath.blend_weight(0.06, 0.6) < 0.1, "starts gently")


func test_box_contains_follows_the_box_rotation() -> void:
	var box := Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(-90.0), 0.0)), Vector3(0.0, 0.0, -100.0))
	var size := Vector3(40.0, 10.0, 4.0)  # Long along local X, which this turn points along world +Z.
	assert_true(CameraMath.box_contains(box, size, Vector3(0.0, 0.0, -85.0)), "15 m along the box's length")
	assert_false(CameraMath.box_contains(box, size, Vector3(15.0, 0.0, -100.0)), "15 m across its width")


func test_speed_effects_ease_in_between_their_start_and_full_speeds() -> void:
	assert_almost_eq(CameraMath.effect_amount(10.0, 12.0, 26.0), 0.0, 1e-6, "nothing below the start")
	assert_almost_eq(CameraMath.effect_amount(19.0, 12.0, 26.0), 0.5, 1e-6, "half way")
	assert_almost_eq(CameraMath.effect_amount(30.0, 12.0, 26.0), 1.0, 1e-6, "full from the full speed on")
