extends "res://tests/test_suite.gd"
## Points, the goal's bonuses and ranks, as GameRules (engine/systems/game_rules.gd) works them out.

var _rules: GameRules


func before_each() -> void:
	_rules = GameRules.new()


func test_badniks_in_a_row_score_more_each() -> void:
	assert_eq([_rules.enemy_points_for(0), _rules.enemy_points_for(1), _rules.enemy_points_for(2), _rules.enemy_points_for(3)], [100, 200, 500, 1000])
	assert_eq(_rules.enemy_points_for(9), 1000, "the last carries on")


func test_the_time_bonus_counts_down_to_nothing_at_twice_the_par() -> void:
	assert_eq(_rules.time_bonus(80.0, 80.0), 24000, "at par")
	assert_eq(_rules.time_bonus(60.0, 80.0), 30000, "faster scores more")
	assert_eq(_rules.time_bonus(160.0, 80.0), 0, "twice the par")
	assert_eq(_rules.time_bonus(300.0, 80.0), 0, "never below nothing")
	assert_eq(_rules.time_bonus(61.234, 80.0), 29630, "in tens")
	assert_eq(_rules.time_bonus(10.0, 0.0), 0, "no par time, no bonus")


func test_the_tally_adds_the_bonuses_to_the_score() -> void:
	var tally := _rules.tally(1500, 80.0, 120, 80.0)
	assert_eq(int(tally["score"]), 1500)
	assert_eq(int(tally["time_bonus"]), 24000)
	assert_eq(int(tally["ring_bonus"]), 12000)
	assert_eq(int(tally["total"]), 37500)


func test_ranks_go_by_the_acts_targets() -> void:
	var targets := PackedInt32Array([50000, 40000, 30000, 20000])
	assert_eq(_rules.rank_of(50000, targets), "S", "exactly the target")
	assert_eq(_rules.rank_of(49999, targets), "A")
	assert_eq(_rules.rank_of(30000, targets), "B")
	assert_eq(_rules.rank_of(20000, targets), "C")
	assert_eq(_rules.rank_of(19999, targets), "D", "below them all")
	assert_eq(_rules.rank_of(0, PackedInt32Array()), "", "no targets, no rank")
