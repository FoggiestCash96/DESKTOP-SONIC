extends Control
## The world map (decided 2026-10-31: a menu map for now; a grander one comes with the art pass). The
## six worlds sit along a path, each with its acts listed on the right with their best time, rings and
## red rings from the save slot. Left and right pick a world, up and down an act; jump plays it. An act
## unlocks when the act before it is cleared, and a world when the one before it is beaten. Back
## returns to the save slots.

const RED_RINGS_PER_ACT := 5  ## Every act hides five red rings (decided 2026-10-30).
const NODE_RADIUS := 54.0
const LOCKED := Color(0.45, 0.48, 0.55)
const PATH_COLOR := Color(1.0, 1.0, 1.0, 0.35)

@export var worlds: WorldList = preload("res://content/sonic/stages/worlds.tres")
@export var map_points: PackedVector2Array = [Vector2(0.12, 0.8), Vector2(0.3, 0.55), Vector2(0.52, 0.72), Vector2(0.64, 0.4), Vector2(0.4, 0.22), Vector2(0.7, 0.12)]  ## Where each world sits, as a share of the map area.
@export_file("*.tscn") var save_select: String = "res://content/sonic/ui/menus/save_select.tscn"

var world := 0  ## The world shown.
var _act_buttons: Array[Button] = []

@onready var _map: Control = %Map
@onready var _world_title: Label = %WorldTitle
@onready var _acts: VBoxContainer = %Acts
@onready var _details: Label = %Details


func _ready() -> void:
	# Back from an act not yet cleared, its act keeps the focus; after a clear, the next act to play.
	var last := worlds.find_act(GameState.stage)
	var unfinished := last.x >= 0 and not SaveData.is_cleared(SaveGame.data, GameState.stage)
	# Whatever is chosen here starts fresh: no checkpoint or clock carried over from the last visit.
	GameState.leave_stage()
	world = maxi(last.x, 0)
	_map.draw.connect(_draw_map)
	_show_world(last.y if unfinished else -1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(save_select)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		world = wrapi(world + (-1 if event.is_action_pressed("ui_left") else 1), 0, worlds.worlds.size())
		_show_world(-1)


func is_world_unlocked(index: int) -> bool:
	var previous := worlds.worlds[index - 1].act_scenes() if index > 0 else PackedStringArray()
	return SaveData.is_world_unlocked(SaveGame.data, previous, worlds.worlds[index].act_scenes())


func is_act_unlocked(world_index: int, act_index: int) -> bool:
	return is_world_unlocked(world_index) and SaveData.is_unlocked(SaveGame.data, worlds.worlds[world_index].act_scenes(), act_index)


## Lists the acts of `world`, focusing act `focus` (or, with -1, the first act still to clear).
func _show_world(focus: int) -> void:
	for button in _act_buttons:
		button.queue_free()
	_act_buttons.clear()
	var info := worlds.worlds[world]
	_world_title.text = info.title.to_upper()
	var first_to_clear := -1
	for i in info.acts.size():
		var act := info.acts[i]
		var button := MenuKit.button(_act_text(i), _play.bind(i))
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 28)
		# Long names trail off rather than widening the list past the screen.
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.disabled = not is_act_unlocked(world, i)
		button.focus_entered.connect(_show_details.bind(i))
		_acts.add_child(button)
		_act_buttons.append(button)
		if first_to_clear < 0 and not button.disabled and not SaveData.is_cleared(SaveGame.data, act.scene):
			first_to_clear = i
	var chosen := focus if focus >= 0 else first_to_clear
	if chosen < 0 or chosen >= _act_buttons.size():
		chosen = 0
	_act_buttons[chosen].grab_focus()
	_show_details(chosen)
	_map.queue_redraw()


func _act_text(index: int) -> String:
	var act := worlds.worlds[world].acts[index]
	var status := ""
	if act.scene == "":
		status = tr("MAP_COMING")
	elif not is_act_unlocked(world, index):
		status = tr("MAP_LOCKED")
	elif SaveData.is_cleared(SaveGame.data, act.scene):
		status = tr("MAP_CLEARED")
	var act_name := ("%s  ·  %s" % [act.title, tr("MAP_BOSS")]) if act.boss else act.title
	return "%s   ·   %s" % [act_name, status] if status != "" else act_name


func _show_details(index: int) -> void:
	var act := worlds.worlds[world].acts[index]
	var lines: PackedStringArray = [act.title]
	if not is_world_unlocked(world):
		lines.append(tr("MAP_WORLD_LOCKED"))
	elif act.scene == "":
		lines.append(tr("MAP_NOT_BUILT"))
	elif not is_act_unlocked(world, index):
		lines.append(tr("MAP_UNLOCK_HINT"))
	elif not SaveData.is_cleared(SaveGame.data, act.scene):
		lines.append(tr("MAP_NOT_CLEARED"))
	else:
		var record := SaveData.act(SaveGame.data, act.scene)
		var best := GameState.format_time(float(record.get("best_time", 0.0)))
		lines.append(tr("MAP_BEST_TIME") % best + (" " + tr("MAP_ASSISTED") if bool(record.get("assisted", false)) else ""))
		lines.append(tr("MAP_BEST_RINGS") % int(record.get("best_rings", 0)))
		lines.append(tr("MAP_RED_RINGS") % [SaveData.red_rings_of(SaveGame.data, act.scene).size(), RED_RINGS_PER_ACT])
	_details.text = "\n".join(lines)


func _play(index: int) -> void:
	var act := worlds.worlds[world].acts[index]
	if act.scene != "" and is_act_unlocked(world, index):
		get_tree().change_scene_to_file(act.scene)


## The worlds along a winding path, the one shown ringed; locked worlds greyed out.
func _draw_map() -> void:
	var area := _map.size
	var font := get_theme_default_font()
	for i in range(1, worlds.worlds.size()):
		_map.draw_line(map_points[i - 1] * area, map_points[i] * area, PATH_COLOR, 6.0, true)
	for i in worlds.worlds.size():
		var center := map_points[i] * area
		var unlocked := is_world_unlocked(i)
		var color := worlds.worlds[i].color if unlocked else LOCKED
		if i == world:
			_map.draw_circle(center, NODE_RADIUS + 12.0, MenuKit.YELLOW)
		_map.draw_circle(center, NODE_RADIUS + 4.0, MenuKit.NAVY)
		_map.draw_circle(center, NODE_RADIUS, color)
		var caption := worlds.worlds[i].title.to_upper()
		var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, 26)
		var at := center + Vector2(-text_size.x * 0.5, NODE_RADIUS + 44.0)
		_map.draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, MenuKit.NAVY)
		_map.draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE if unlocked else Color(1, 1, 1, 0.55))
