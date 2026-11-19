extends "res://tests/test_suite.gd"
## Save slot data in engine/systems/save_data.gd.

const ACT_1 := "res://stages/act_1.tscn"
const ACT_2 := "res://stages/act_2.tscn"
const ACT_8 := "res://stages/act_8.tscn"


func test_a_first_clear_records_everything() -> void:
	var slot := SaveData.new_slot()
	var improved := SaveData.record_clear(slot, ACT_1, 81.5, 61, PackedStringArray(["Gimmicks/RedRing1", "Gimmicks/RedRing3"]), false)
	assert_true(bool(improved["first_clear"]) and bool(improved["best_time"]) and bool(improved["best_rings"]), str(improved))
	assert_eq(int(improved["new_red_rings"]), 2)
	assert_true(SaveData.is_cleared(slot, ACT_1))
	assert_almost_eq(float(SaveData.act(slot, ACT_1)["best_time"]), 81.5)
	assert_eq(SaveData.red_rings_of(slot, ACT_1), PackedStringArray(["Gimmicks/RedRing1", "Gimmicks/RedRing3"]))


func test_later_clears_keep_the_best_and_add_red_rings() -> void:
	var slot := SaveData.new_slot()
	SaveData.record_clear(slot, ACT_1, 81.5, 61, PackedStringArray(["Gimmicks/RedRing1"]), false)
	var slower := SaveData.record_clear(slot, ACT_1, 90.0, 70, PackedStringArray(["Gimmicks/RedRing1", "Gimmicks/RedRing2"]), false)
	assert_false(bool(slower["first_clear"]) or bool(slower["best_time"]), "a slower time isn't a best")
	assert_true(bool(slower["best_rings"]), "more rings is a best")
	assert_eq(int(slower["new_red_rings"]), 1, "only the newly found red ring counts")
	var record := SaveData.act(slot, ACT_1)
	assert_almost_eq(float(record["best_time"]), 81.5, 1e-5, "the faster time stays")
	assert_eq(int(record["best_rings"]), 70)
	assert_eq(SaveData.red_rings_of(slot, ACT_1).size(), 2)
	SaveData.record_clear(slot, ACT_1, 70.0, 10, PackedStringArray([]), true)
	assert_true(bool(SaveData.act(slot, ACT_1)["assisted"]), "a best time set with an assist says so")


func test_the_best_score_keeps_its_rank_and_says_if_assisted() -> void:
	var slot := SaveData.new_slot()
	var first := SaveData.record_clear(slot, ACT_1, 80.0, 50, PackedStringArray(), false, 30000, "B")
	assert_true(bool(first["best_score"]))
	var lower := SaveData.record_clear(slot, ACT_1, 70.0, 50, PackedStringArray(), false, 20000, "C")
	assert_false(bool(lower["best_score"]), "a lower score isn't a best")
	assert_eq(str(SaveData.act(slot, ACT_1)["best_rank"]), "B", "the best score's rank stays")
	var higher := SaveData.record_clear(slot, ACT_1, 90.0, 50, PackedStringArray(), true, 45000, "S")
	assert_true(bool(higher["best_score"]))
	var record := SaveData.act(slot, ACT_1)
	assert_eq(int(record["best_score"]), 45000)
	assert_eq(str(record["best_rank"]), "S")
	assert_true(bool(record["score_assisted"]), "a best score set with an assist says so")
	assert_false(bool(record["assisted"]), "the best time, set without one, doesn't")


func test_a_time_attack_record_keeps_the_fastest_run_and_its_splits() -> void:
	var slot := SaveData.new_slot()
	SaveData.record_clear(slot, ACT_1, 80.0, 50, PackedStringArray(), false, 30000, "B")
	var first := SaveData.record_time_attack(slot, ACT_1, 75.5, {"Checkpoint1": 30.25}, false)
	assert_true(bool(first["first_clear"]) and bool(first["best_time"]), str(first))
	var slower := SaveData.record_time_attack(slot, ACT_1, 77.0, {"Checkpoint1": 29.0}, false)
	assert_false(bool(slower["first_clear"]) or bool(slower["best_time"]), "a slower run isn't kept")
	assert_almost_eq(float(SaveData.splits_of(slot, ACT_1)["Checkpoint1"]), 30.25, 1e-5, "the fastest run's splits")
	SaveData.record_clear(slot, ACT_1, 85.0, 40, PackedStringArray(), false, 25000, "C")
	var back := SaveData.from_json(SaveData.to_json(slot))
	assert_almost_eq(float(SaveData.act(back, ACT_1)["ta_time"]), 75.5, 1e-5, "a clear keeps the time attack record, through JSON too")
	assert_almost_eq(float(SaveData.splits_of(back, ACT_1)["Checkpoint1"]), 30.25)
	assert_almost_eq(float(SaveData.act(back, ACT_1)["best_time"]), 80.0, 1e-5, "time attack runs leave the act's best time alone")
	assert_true(SaveData.splits_of(slot, ACT_2).is_empty(), "no run, no splits")


func test_time_attack_keeps_the_three_fastest_runs() -> void:
	var slot := SaveData.new_slot()
	for run: Array in [[80.0, false], [75.0, true], [90.0, false], [70.0, false]]:
		SaveData.record_time_attack(slot, ACT_1, float(run[0]), {}, bool(run[1]))
	var runs := SaveData.time_attack_runs(SaveData.from_json(SaveData.to_json(slot)), ACT_1)
	assert_eq(runs.size(), 3, "only the fastest three")
	assert_eq([float(runs[0]["time"]), float(runs[1]["time"]), float(runs[2]["time"])], [70.0, 75.0, 80.0], "fastest first")
	assert_true(bool(runs[1]["assisted"]) and not bool(runs[0]["assisted"]), "each says whether an assist was on")
	var older := SaveData.from_json('{"version": 1, "acts": {"%s": {"cleared": true, "ta_time": 64.5, "ta_assisted": false}}}' % ACT_1)
	assert_almost_eq(float(SaveData.time_attack_runs(older, ACT_1)[0]["time"]), 64.5, 1e-5, "a record from before keeps its one run")


func test_a_clear_saved_before_scores_existed_takes_a_score() -> void:
	var slot := SaveData.from_json('{"version": 1, "acts": {"%s": {"cleared": true, "best_time": 80.0, "assisted": false, "best_rings": 50, "red_rings": []}}}' % ACT_1)
	var improved := SaveData.record_clear(slot, ACT_1, 90.0, 10, PackedStringArray(), false, 1000, "D")
	assert_true(bool(improved["best_score"]) and not bool(improved["first_clear"]), str(improved))
	assert_eq(str(SaveData.act(slot, ACT_1)["best_rank"]), "D")


func test_acts_unlock_in_order_skipping_ones_not_built() -> void:
	var slot := SaveData.new_slot()
	var acts := PackedStringArray([ACT_1, "", "", ACT_8])
	assert_true(SaveData.is_unlocked(slot, acts, 0), "the first act is open from the start")
	assert_false(SaveData.is_unlocked(slot, acts, 1), "an act that isn't built never is")
	assert_false(SaveData.is_unlocked(slot, acts, 3), "the boss waits for the act before it")
	SaveData.record_clear(slot, ACT_1, 80.0, 50, PackedStringArray([]), false)
	assert_true(SaveData.is_unlocked(slot, acts, 3), "clearing act 1 opens the next built act")
	assert_false(SaveData.is_unlocked(slot, acts, 9), "out of range")


func test_a_world_opens_once_the_one_before_is_beaten() -> void:
	var slot := SaveData.new_slot()
	var first := PackedStringArray([ACT_1, ACT_8])
	var second := PackedStringArray([ACT_2, ""])
	assert_true(SaveData.is_world_unlocked(slot, PackedStringArray(), first), "the first world is always open")
	assert_false(SaveData.is_world_unlocked(slot, first, second), "not before its boss is beaten")
	SaveData.record_clear(slot, ACT_8, 60.0, 0, PackedStringArray([]), false)
	assert_true(SaveData.is_world_unlocked(slot, first, second))
	assert_false(SaveData.is_world_unlocked(slot, first, PackedStringArray(["", ""])), "a world with nothing built stays shut")


func test_the_summary_adds_up_the_slot() -> void:
	var slot := SaveData.new_slot()
	SaveData.record_clear(slot, ACT_1, 80.0, 50, PackedStringArray(["A", "B"]), false)
	SaveData.record_clear(slot, ACT_8, 60.0, 5, PackedStringArray(["C"]), false)
	slot["play_time"] = 754.0
	var totals := SaveData.summary(slot)
	assert_eq(int(totals["cleared"]), 2)
	assert_eq(int(totals["red_rings"]), 3)
	assert_almost_eq(float(totals["play_time"]), 754.0)


func test_a_slot_survives_json_and_bad_files_are_refused() -> void:
	var slot := SaveData.new_slot()
	SaveData.record_clear(slot, ACT_1, 81.25, 61, PackedStringArray(["Gimmicks/RedRing5"]), true)
	var back := SaveData.from_json(SaveData.to_json(slot))
	assert_true(SaveData.is_cleared(back, ACT_1))
	assert_almost_eq(float(SaveData.act(back, ACT_1)["best_time"]), 81.25)
	assert_eq(SaveData.red_rings_of(back, ACT_1), PackedStringArray(["Gimmicks/RedRing5"]))
	assert_true(SaveData.from_json("not json at all").is_empty(), "garbage")
	assert_true(SaveData.from_json('{"version": 99, "acts": {}}').is_empty(), "a newer version")
	assert_true(SaveData.from_json('{"version": 1, "acts": []}').is_empty(), "acts of the wrong type")
