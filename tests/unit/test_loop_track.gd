extends "res://tests/test_suite.gd"
## Shape of the generated loop in engine/gimmicks/loop_track.gd.

const RADIUS := 4.0
const OFFSET := 5.0


func test_loop_starts_flat_at_its_origin() -> void:
	assert_almost_eq(LoopTrack.center_point(0.0, RADIUS, OFFSET).length(), 0.0, 1e-6, "starts at the origin")
	assert_almost_eq(LoopTrack.surface_normal(0.0).dot(Vector3.UP), 1.0, 1e-6, "starts flat")


func test_loop_is_upside_down_at_the_top() -> void:
	var top := LoopTrack.center_point(PI, RADIUS, OFFSET)
	assert_almost_eq(top.y, RADIUS * 2.0, 1e-5, "top is a diameter up")
	assert_almost_eq(top.x, OFFSET * 0.5, 1e-5, "halfway across")
	assert_almost_eq(LoopTrack.surface_normal(PI).dot(Vector3.DOWN), 1.0, 1e-6, "surface faces down")


func test_loop_ends_flat_beside_the_entry() -> void:
	var end := LoopTrack.center_point(TAU, RADIUS, OFFSET)
	assert_almost_eq(end.x, OFFSET, 1e-5, "shifted by the exit offset")
	assert_almost_eq(Vector2(end.y, end.z).length(), 0.0, 1e-5, "back on the ground at the start line")
	assert_almost_eq(LoopTrack.surface_normal(TAU).dot(Vector3.UP), 1.0, 1e-6, "ends flat")


func test_surface_faces_the_middle_of_the_loop() -> void:
	for step in 8:
		var angle := TAU * step / 8.0
		var point := LoopTrack.center_point(angle, RADIUS, OFFSET)
		var to_middle := Vector3(0.0, RADIUS, 0.0) - Vector3(0.0, point.y, point.z)
		assert_almost_eq(LoopTrack.surface_normal(angle).dot(to_middle.normalized()), 1.0, 1e-5, "at %.0f°" % rad_to_deg(angle))
