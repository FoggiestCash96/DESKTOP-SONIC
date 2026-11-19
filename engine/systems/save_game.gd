extends Node
## The save slots: SLOTS files of JSON in `directory`, each holding one game's progress (SaveData),
## with a folder beside it for the ghosts of its fastest time attack runs (GhostRun). Autoloaded as
## SaveGame. The slot screen starts a slot (new or saved); clearing an act records it and saves at
## once. With no slot started, as when a stage is run on its own, nothing is saved.

signal saved

const SLOTS := 10

var directory := "user://saves"  ## Where the slot files live. Tests point this somewhere else.
var slot := -1  ## The slot being played, from 0, or -1 with none started.
var data: Dictionary = {}  ## The started slot (SaveData).


func _process(delta: float) -> void:
	if slot >= 0 and not get_tree().paused:
		# Real time played, whatever the game speed.
		data["play_time"] = float(data.get("play_time", 0.0)) + delta / maxf(Engine.time_scale, 0.01)


func has_slot() -> bool:
	return slot >= 0


func path_of(index: int) -> String:
	return "%s/slot_%02d.json" % [directory, index + 1]


func exists(index: int) -> bool:
	return FileAccess.file_exists(path_of(index))


## The saved slot `index` without starting it, or an empty Dictionary if there is none.
func peek(index: int) -> Dictionary:
	if not exists(index):
		return {}
	return SaveData.from_json(FileAccess.get_file_as_string(path_of(index)))


## Starts playing slot `index`: its saved game, or a new one if it is empty (or unreadable).
func start(index: int) -> void:
	data = peek(index)
	if data.is_empty():
		data = SaveData.new_slot()
	slot = index
	save()


## Saves and stops playing the started slot.
func close() -> void:
	save()
	slot = -1
	data = {}


## Deletes slot `index`. Returns whether it is gone.
func delete(index: int) -> bool:
	if index == slot:
		slot = -1
		data = {}
	var ghosts := _ghost_directory(index)
	if DirAccess.dir_exists_absolute(ghosts):
		for file in DirAccess.get_files_at(ghosts):
			DirAccess.remove_absolute(ghosts.path_join(file))
		DirAccess.remove_absolute(ghosts)
	if not exists(index):
		return true
	return DirAccess.remove_absolute(path_of(index)) == OK


## Writes the started slot. It goes to a temporary file first, so a crash mid-write can't leave
## half a save behind. Returns whether it worked.
func save() -> bool:
	if slot < 0:
		return false
	DirAccess.make_dir_recursive_absolute(directory)
	var temporary := path_of(slot) + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s: %s" % [temporary, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(SaveData.to_json(data))
	file.close()
	var error := DirAccess.rename_absolute(temporary, path_of(slot))
	if error != OK:
		push_error("Can't save %s: %s" % [path_of(slot), error_string(error)])
		return false
	saved.emit()
	return true


## Records clearing an act (SaveData.record_clear()) and saves. Returns what improved, or an empty
## Dictionary with no slot started.
func record_clear(act_id: String, time: float, rings: int, found: PackedStringArray, assisted: bool, score := 0, rank := "") -> Dictionary:
	if slot < 0:
		return {}
	var improved := SaveData.record_clear(data, act_id, time, rings, found, assisted, score, rank)
	save()
	return improved


## Records a time attack run (SaveData.record_time_attack()) and saves. Returns what improved, or
## an empty Dictionary with no slot started.
func record_time_attack(act_id: String, time: float, splits: Dictionary, assisted: bool) -> Dictionary:
	if slot < 0:
		return {}
	var improved := SaveData.record_time_attack(data, act_id, time, splits, assisted)
	save()
	return improved


## Where the started slot keeps the ghost of its fastest time attack run of the act at `act_id`.
func ghost_path(act_id: String) -> String:
	return "%s/%s.ghost" % [_ghost_directory(slot), act_id.md5_text()]


## Saves `run` (GhostRun.to_dict()) as the started slot's ghost for the act at `act_id`, through a
## temporary file like save(). Returns whether it worked.
func save_ghost(act_id: String, run: Dictionary) -> bool:
	if slot < 0:
		return false
	DirAccess.make_dir_recursive_absolute(_ghost_directory(slot))
	var path := ghost_path(act_id)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s: %s" % [path + ".tmp", error_string(FileAccess.get_open_error())])
		return false
	file.store_var(run)
	file.close()
	var error := DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		push_error("Can't save %s: %s" % [path, error_string(error)])
		return false
	return true


## The started slot's ghost for the act at `act_id` (GhostRun.to_dict()), or an empty Dictionary.
func load_ghost(act_id: String) -> Dictionary:
	if slot < 0 or not FileAccess.file_exists(ghost_path(act_id)):
		return {}
	var file := FileAccess.open(ghost_path(act_id), FileAccess.READ)
	if file == null:
		return {}
	var run: Variant = file.get_var()  # Never decodes objects.
	return run if run is Dictionary else {}


func act(act_id: String) -> Dictionary:
	return SaveData.act(data, act_id)


## Ids of the hidden collectibles found in the act at `act_id` on the started slot.
func red_rings(act_id: String) -> PackedStringArray:
	return SaveData.red_rings_of(data, act_id)


func _ghost_directory(index: int) -> String:
	return "%s/slot_%02d_ghosts" % [directory, index + 1]
