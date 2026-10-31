class_name SaveData
extends RefCounted
## A save slot as plain data, kept free of nodes and files so the unit tests can check it. A slot is
## a Dictionary that converts to and from JSON:
##   version    the format version (VERSION)
##   play_time  seconds played on the slot
##   acts       act scene path -> {cleared, best_time, assisted, best_rings, red_rings}
## `assisted` says whether the best time was set with an assist on, and `red_rings` lists the ids of
## the hidden collectibles ever found in the act. SaveGame (autoload) reads and writes the slots.

const VERSION := 1


static func new_slot() -> Dictionary:
	return {"version": VERSION, "play_time": 0.0, "acts": {}}


## Records clearing the act at `act_id` in `slot`: the best time and best ring count so far, and every
## hidden collectible ever found there (`found` adds to them). Returns what improved, as
## {first_clear, best_time, best_rings, new_red_rings}.
static func record_clear(slot: Dictionary, act_id: String, time: float, rings: int, found: PackedStringArray, assisted: bool) -> Dictionary:
	var acts: Dictionary = slot.get_or_add("acts", {})
	var before := act(slot, act_id)
	var first := not bool(before.get("cleared", false))
	var faster := first or time < float(before.get("best_time", INF))
	var richer := first or rings > int(before.get("best_rings", -1))
	var red_rings := red_rings_of(slot, act_id)
	var added := 0
	for id in found:
		if not red_rings.has(id):
			red_rings.append(id)
			added += 1
	red_rings.sort()
	acts[act_id] = {
		"cleared": true,
		"best_time": time if faster else float(before.get("best_time", time)),
		"assisted": assisted if faster else bool(before.get("assisted", false)),
		"best_rings": rings if richer else int(before.get("best_rings", rings)),
		"red_rings": Array(red_rings),
	}
	return {"first_clear": first, "best_time": faster, "best_rings": richer, "new_red_rings": added}


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
