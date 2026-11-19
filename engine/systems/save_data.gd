class_name SaveData
extends RefCounted
## A save slot as plain data, kept free of nodes and files so the unit tests can check it. A slot is
## a Dictionary that converts to and from JSON:
##   version    the format version (VERSION)
##   play_time  seconds played on the slot
##   acts       act scene path -> {cleared, best_time, assisted, best_rings, red_rings, best_score,
##              best_rank, score_assisted, ta_time, ta_assisted, ta_splits, ta_runs}
## `assisted` says whether the best time was set with an assist on (`score_assisted` the same for the
## best score). `red_rings` lists the ids of the hidden collectibles ever found in the act, and
## `best_rank` is the rank the best score earned. The `ta_` keys are time attack's: the fastest run's
## time, whether an assist was on and the stage clock at each checkpoint (by id), and `ta_runs`, the
## fastest TIME_ATTACK_RUNS runs as {time, assisted}, fastest first. An act with no time attack run
## has none of them. SaveGame (autoload) reads and writes the slots.

const VERSION := 1
const TIME_ATTACK_RUNS := 3  ## Time attack runs each act keeps, fastest first.


static func new_slot() -> Dictionary:
	return {"version": VERSION, "play_time": 0.0, "acts": {}}


## Records clearing the act at `act_id` in `slot`: the best time, ring count and goal total (`score`,
## with the `rank` it earned) so far, and every hidden collectible ever found there (`found` adds to
## them). Returns what improved, as {first_clear, best_time, best_rings, best_score, new_red_rings}.
static func record_clear(slot: Dictionary, act_id: String, time: float, rings: int, found: PackedStringArray, assisted: bool, score := 0, rank := "") -> Dictionary:
	var acts: Dictionary = slot.get_or_add("acts", {})
	var before := act(slot, act_id)
	var first := not bool(before.get("cleared", false))
	var faster := first or time < float(before.get("best_time", INF))
	var richer := first or rings > int(before.get("best_rings", -1))
	var higher := first or score > int(before.get("best_score", -1))
	var red_rings := red_rings_of(slot, act_id)
	var added := 0
	for id in found:
		if not red_rings.has(id):
			red_rings.append(id)
			added += 1
	red_rings.sort()
	var record := before.duplicate()  # Keeps the time attack record.
	record["cleared"] = true
	record["best_time"] = time if faster else float(before.get("best_time", time))
	record["assisted"] = assisted if faster else bool(before.get("assisted", false))
	record["best_rings"] = rings if richer else int(before.get("best_rings", rings))
	record["red_rings"] = Array(red_rings)
	if higher:
		record["best_score"] = score
		record["best_rank"] = rank
		record["score_assisted"] = assisted
	acts[act_id] = record
	return {"first_clear": first, "best_time": faster, "best_rings": richer, "best_score": higher, "new_red_rings": added}


## Records a time attack run of the act at `act_id` in `slot` that reached the goal in `time`, with
## the stage clock at each checkpoint it passed (`splits`, by id). The fastest run keeps its splits,
## and the fastest TIME_ATTACK_RUNS keep their times. Returns {first_clear, best_time}: whether it was
## the act's first time attack run, and the fastest.
static func record_time_attack(slot: Dictionary, act_id: String, time: float, splits: Dictionary, assisted: bool) -> Dictionary:
	var acts: Dictionary = slot.get_or_add("acts", {})
	var runs := time_attack_runs(slot, act_id)
	var record := act(slot, act_id).duplicate()
	var first := not record.has("ta_time")
	var faster := first or time < float(record.get("ta_time", INF))
	if faster:
		record["ta_time"] = time
		record["ta_assisted"] = assisted
		record["ta_splits"] = splits.duplicate()
	runs.append({"time": time, "assisted": assisted})
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	record["ta_runs"] = runs.slice(0, TIME_ATTACK_RUNS)
	acts[act_id] = record
	return {"first_clear": first, "best_time": faster}


## The fastest time attack runs of the act at `act_id`, fastest first, as {time, assisted}.
static func time_attack_runs(slot: Dictionary, act_id: String) -> Array[Dictionary]:
	var record := act(slot, act_id)
	var runs: Array[Dictionary] = []
	var listed: Variant = record.get("ta_runs")
	if listed is Array:
		for run: Variant in listed:
			var time: Variant = (run as Dictionary).get("time") if run is Dictionary else null
			if time is float or time is int:
				runs.append({"time": float(time), "assisted": bool((run as Dictionary).get("assisted", false))})
	elif record.has("ta_time"):  # Saved before the fastest few were kept.
		runs.append({"time": float(record["ta_time"]), "assisted": bool(record.get("ta_assisted", false))})
	return runs


## The stage clock at each checkpoint (by id) on the fastest time attack run of the act at `act_id`.
static func splits_of(slot: Dictionary, act_id: String) -> Dictionary:
	var splits: Variant = act(slot, act_id).get("ta_splits", {})
	return splits if splits is Dictionary else {}


## The record of the act at `act_id`, or an empty one if it has never been cleared.
static func act(slot: Dictionary, act_id: String) -> Dictionary:
	var acts: Dictionary = slot.get("acts", {})
	var record: Variant = acts.get(act_id, {})
	return record if record is Dictionary else {}


static func is_cleared(slot: Dictionary, act_id: String) -> bool:
	return bool(act(slot, act_id).get("cleared", false))


## Ids of the hidden collectibles ever found in the act at `act_id`.
static func red_rings_of(slot: Dictionary, act_id: String) -> PackedStringArray:
	var ids: PackedStringArray = []
	var listed: Variant = act(slot, act_id).get("red_rings", [])
	if listed is Array:
		for id: Variant in listed:
			ids.append(str(id))
	return ids


## Whether the act at `index` in a world's acts (their scene paths in order, "" for acts not built
## yet) can be played: it is built, and it is the world's first built act or the built act before it
## has been cleared.
static func is_unlocked(slot: Dictionary, acts: PackedStringArray, index: int) -> bool:
	if index < 0 or index >= acts.size() or acts[index] == "":
		return false
	for i in range(index - 1, -1, -1):
		if acts[i] != "":
			return is_cleared(slot, acts[i])
	return true


## Whether a world can be visited: the first world always, any other once the last built act of the
## world before it (`previous`, as in is_unlocked()) has been cleared, as long as it has an act built.
static func is_world_unlocked(slot: Dictionary, previous: PackedStringArray, acts: PackedStringArray) -> bool:
	var built := false
	for scene in acts:
		built = built or scene != ""
	if not built:
		return false
	for i in range(previous.size() - 1, -1, -1):
		if previous[i] != "":
			return is_cleared(slot, previous[i])
	return true


## Totals for the slot screen: {cleared (acts), red_rings, play_time}.
static func summary(slot: Dictionary) -> Dictionary:
	var cleared := 0
	var red_rings := 0
	var acts: Dictionary = slot.get("acts", {})
	for act_id: Variant in acts:
		if is_cleared(slot, str(act_id)):
			cleared += 1
		red_rings += red_rings_of(slot, str(act_id)).size()
	return {"cleared": cleared, "red_rings": red_rings, "play_time": float(slot.get("play_time", 0.0))}


static func to_json(slot: Dictionary) -> String:
	return JSON.stringify(slot, "\t")


## Reads a slot written by to_json(). Anything unreadable, or from a newer version of the game,
## gives an empty Dictionary.
static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var slot: Dictionary = json.data
	if int(slot.get("version", 0)) < 1 or int(slot.get("version", 0)) > VERSION or not slot.get("acts") is Dictionary:
		return {}
	slot["play_time"] = maxf(float(slot.get("play_time", 0.0)), 0.0)
	return slot
