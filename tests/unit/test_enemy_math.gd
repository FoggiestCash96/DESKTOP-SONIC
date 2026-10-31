extends "res://tests/test_suite.gd"
## Enemy and boss math in engine/enemies/base/enemy_math.gd.


func test_a_leap_rises_to_its_height_and_comes_back_down() -> void:
	assert_almost_eq(EnemyMath.leap_height(0.0, 4.0), 0.0, 1e-6, "starts at its spot")
	assert_almost_eq(EnemyMath.leap_height(0.5, 4.0), 4.0, 1e-6, "highest halfway")
	assert_almost_eq(EnemyMath.leap_height(1.0, 4.0), 0.0, 1e-6, "lands back at its spot")
	assert_almost_eq(EnemyMath.leap_height(0.25, 4.0), EnemyMath.leap_height(0.75, 4.0), 1e-6, "the same on the way up and down")


func test_a_leaper_points_its_nose_along_the_arc() -> void:
	assert_almost_eq(EnemyMath.leap_pitch(0.0, 4.0, 0.0), PI * 0.5, 1e-6, "straight up when leaping on the spot")
	assert_almost_eq(EnemyMath.leap_pitch(1.0, 4.0, 0.0), -PI * 0.5, 1e-6, "straight down coming back")
	assert_almost_eq(EnemyMath.leap_pitch(0.5, 4.0, 8.0), 0.0, 1e-6, "level at the top")
	assert_true(EnemyMath.leap_pitch(0.1, 4.0, 8.0) > 0.0, "nose up while rising")


func test_a_boss_changes_phase_at_its_hits_left() -> void:
	var changes: Array[int] = [4, 2]
	var phases: Array[int] = []
	for hits_left in range(8, -1, -1):
		phases.append(EnemyMath.boss_phase(hits_left, changes))
	assert_eq(phases, [0, 0, 0, 0, 1, 1, 2, 2, 2] as Array[int], "8 hits, faster at 4 and 2 left")
	var none: Array[int] = []
	assert_eq(EnemyMath.boss_phase(1, none), 0, "a boss without phase changes stays in its first phase")
