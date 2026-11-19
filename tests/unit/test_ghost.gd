extends "res://tests/test_suite.gd"
## Time attack ghosts: recording a run and playing it back (engine/player/ghost_run.gd).


func test_samples_come_no_closer_than_the_interval() -> void:
	var run := GhostRun.new()
	run.add(0.0, Transform3D.IDENTITY, &"ground", 0.0)
	run.add(1.0 / 120.0, Transform3D.IDENTITY, &"ground", 0.0)  # A tick later: too soon.
	run.add(4.0 / 120.0, Transform3D.IDENTITY, &"ground", 0.0)  # Four ticks: one interval.
	assert_eq(run.times.size(), 2)
	run.add(5.0 / 120.0, Transform3D.IDENTITY, &"victory", 0.0, true)
	assert_eq(run.times.size(), 3, "the goal's sample is always added")
	run.add(5.0 / 120.0, Transform3D.IDENTITY, &"victory", 0.0, true)
	assert_eq(run.times.size(), 3, "but never out of order")


func test_playback_moves_between_the_samples() -> void:
	var run := GhostRun.new()
	run.add(1.0, _turned(0.0, Vector3.ZERO), &"ground", 10.0)
	run.add(2.0, _turned(PI / 2.0, Vector3(10, 0, 0)), &"ball", 20.0)
	var middle := run.sample(1.5)
	assert_true((middle["transform"] as Transform3D).origin.is_equal_approx(Vector3(5, 0, 0)), "halfway there")
	assert_almost_eq((middle["transform"] as Transform3D).basis.get_euler().y, PI / 4.0, 1e-4, "halfway round")
	assert_almost_eq(float(middle["speed"]), 15.0)
	assert_eq(run.sample(1.2)["pose"], &"ground", "the nearer sample's pose")
	assert_eq(run.sample(1.8)["pose"], &"ball")
	assert_true((run.sample(0.0)["transform"] as Transform3D).origin.is_equal_approx(Vector3.ZERO), "before the run: at its start")
	assert_true((run.sample(9.0)["transform"] as Transform3D).origin.is_equal_approx(Vector3(10, 0, 0)), "after it: at its end")
	assert_almost_eq(run.duration(), 2.0)
	assert_true(GhostRun.new().sample(1.0).is_empty(), "nothing recorded")


func test_a_run_survives_saving_and_bad_data_is_refused() -> void:
	var run := GhostRun.new()
	for i in 10:
		run.add(i * 0.1, _turned(i * 0.2, Vector3(i, 1, 0)), &"ground", float(i))
	var back := GhostRun.new()
	assert_true(back.from_dict(bytes_to_var(var_to_bytes(run.to_dict()))), "read back as SaveGame stores it")
	assert_eq(back.times.size(), 10)
	assert_true((back.sample(0.45)["transform"] as Transform3D).origin.is_equal_approx(Vector3(4.5, 1, 0)))
	var damaged := run.to_dict()
	damaged["poses"] = PackedByteArray([0, 1])
	assert_false(GhostRun.new().from_dict(damaged), "arrays of different lengths")
	assert_false(GhostRun.new().from_dict({"version": 99}), "a newer version")
	assert_false(GhostRun.new().from_dict({}), "nothing")


func _turned(yaw: float, at: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at)
