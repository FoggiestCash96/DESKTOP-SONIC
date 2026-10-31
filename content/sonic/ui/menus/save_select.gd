extends Control
## The save slots (decided 2026-10-31: ten, each with its own progress, saved after every act). Pick
## one to carry on, or an empty one to start a new game; either way the world map follows. The
## special button (F or Y) deletes the chosen slot, after asking. Back returns to the title screen.

@export_file("*.tscn") var world_map: String = "res://content/sonic/ui/map/world_map.tscn"
@export_file("*.tscn") var title_screen: String = "res://content/sonic/ui/title/title_screen.tscn"

var _slot_buttons: Array[Button] = []
var _deleting := -1

@onready var _slots: VBoxContainer = %Slots
@onready var _confirm: Control = %Confirm
@onready var _confirm_label: Label = %ConfirmLabel
@onready var _confirm_buttons: HBoxContainer = %ConfirmButtons


func _ready() -> void:
	if SaveGame.has_slot():
		SaveGame.close()
	for i in SaveGame.SLOTS:
		var button := MenuKit.button("", _start.bind(i))
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_slots.add_child(button)
		_slot_buttons.append(button)
	_confirm_buttons.add_child(MenuKit.button("SAVE_DELETE_YES", _confirm_delete))
	_confirm_buttons.add_child(MenuKit.button("SAVE_DELETE_NO", _cancel_delete))
	_confirm.visible = false
	_refresh()
	_slot_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_cancel_delete()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(title_screen)
	elif event.is_action_pressed("special") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_DELETE and event.is_pressed()):
		var focused := _slot_buttons.find(get_viewport().gui_get_focus_owner() as Button)
		if focused >= 0 and SaveGame.exists(focused):
			get_viewport().set_input_as_handled()
			_ask_delete(focused)


## The text a slot's button shows: its number, then a new game or its progress.
func describe(index: int) -> String:
	var heading := tr("SAVE_SLOT") % (index + 1)
	if not SaveGame.exists(index):
		return "%s\n%s" % [heading, tr("SAVE_NEW")]
	var totals := SaveData.summary(SaveGame.peek(index))
	var seconds := int(totals["play_time"])
	var played := "%d:%02d:%02d" % [floori(seconds / 3600.0), floori(seconds / 60.0) % 60, seconds % 60]
	return "%s\n%s" % [heading, tr("SAVE_PROGRESS") % [int(totals["cleared"]), int(totals["red_rings"]), played]]


func _set_slots_focusable(on: bool) -> void:
	for button in _slot_buttons:
		button.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _refresh() -> void:
	for i in _slot_buttons.size():
		_slot_buttons[i].text = describe(i)


func _start(index: int) -> void:
	SaveGame.start(index)
	GameState.new_game()
	get_tree().change_scene_to_file(world_map)


func _ask_delete(index: int) -> void:
	_deleting = index
	_confirm_label.text = tr("SAVE_DELETE_CONFIRM") % (index + 1)
	_confirm.visible = true
	_set_slots_focusable(false)  # Keeps the focus in the question, not on the slots behind it.
	(_confirm_buttons.get_child(1) as Button).grab_focus()


func _confirm_delete() -> void:
	SaveGame.delete(_deleting)
	_close_confirm()


func _cancel_delete() -> void:
	_close_confirm()


func _close_confirm() -> void:
	var index := _deleting
	_deleting = -1
	_confirm.visible = false
	_set_slots_focusable(true)
	_refresh()
	_slot_buttons[maxi(index, 0)].grab_focus()
