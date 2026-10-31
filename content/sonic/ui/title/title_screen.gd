extends Control
## Title screen. Shows the fan-game disclaimer; Enter, A or Start brings up the main menu: play (the
## save slots, then the world map), the options, the greybox test room, and quit. Two developer
## shortcuts skip the menus without a save slot: the special button (F or Y) opens the test room and
## the boost button (Shift or X) Act 8's boss.

@export_file("*.tscn") var save_select: String = "res://content/sonic/ui/menus/save_select.tscn"
## Scene loaded for the test room: the greybox room for trying the physics and gimmicks.
@export_file("*.tscn") var test_room: String = "res://stages/greybox/test_room.tscn"
## Scene loaded with the boost button: the act with the first boss.
@export_file("*.tscn") var boss_scene: String = "res://content/sonic/stages/emerald_shore/act_8.tscn"
@export var options_scene: PackedScene = preload("res://content/sonic/ui/menus/options_menu.tscn")

var _options: Control

@onready var _version_label: Label = %VersionLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _menu: VBoxContainer = %Menu


func _ready() -> void:
	if SaveGame.has_slot():
		SaveGame.close()
	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	_version_label.text = "v%s  ·  pre-alpha" % version
	var blink := create_tween().set_loops()
	blink.tween_property(_prompt_label, "modulate:a", 0.25, 0.6)
	blink.tween_property(_prompt_label, "modulate:a", 1.0, 0.6)
	_menu.add_child(MenuKit.button("MENU_PLAY", func() -> void: get_tree().change_scene_to_file(save_select)))
	_menu.add_child(MenuKit.button("MENU_OPTIONS", _open_options))
	_menu.add_child(MenuKit.button("MENU_TEST_ROOM", _play_without_slot.bind(test_room)))
	if OS.get_name() != "Web":
		_menu.add_child(MenuKit.button("MENU_QUIT", func() -> void: get_tree().quit()))
	_menu.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _options:
		return
	if _menu.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_show_menu(false)
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_show_menu(true)
	elif event.is_action_pressed("special"):
		get_viewport().set_input_as_handled()
		_play_without_slot(test_room)
	elif event.is_action_pressed("boost"):
		get_viewport().set_input_as_handled()
		_play_without_slot(boss_scene)


func is_menu_open() -> bool:
	return _menu.visible


func _show_menu(on: bool) -> void:
	_menu.visible = on
	_prompt_label.visible = not on
	if on:
		MenuKit.focus_first(_menu)


func _open_options() -> void:
	_options = options_scene.instantiate() as Control
	add_child(_options)
	_menu.visible = false  # Hidden behind the options, so the focus can't wander back to it.
	_options.connect("closed", func() -> void:
		_options = null
		_menu.visible = true
		MenuKit.focus_first(_menu))


func _play_without_slot(scene: String) -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(scene)
