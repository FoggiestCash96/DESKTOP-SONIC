extends CanvasLayer
## The pause menu. Start or Esc during a stage pauses the game and brings it up: resume, restart
## from the last checkpoint, restart the act, change the options, or quit to the world map (or the
## title screen, with no save slot). It keeps working while the game is paused.

@export var options_scene: PackedScene = preload("res://content/sonic/ui/menus/options_menu.tscn")

var _options: Control
var _checkpoint_button: Button
var _quit_button: Button

@onready var _buttons: VBoxContainer = %Buttons
@onready var _screen: Control = $Screen


func _ready() -> void:
	visible = false
	_buttons.add_child(MenuKit.button("PAUSE_RESUME", resume))
	_checkpoint_button = MenuKit.button("PAUSE_RESTART_CHECKPOINT", func() -> void: _stage().restart_from_checkpoint())
	_buttons.add_child(_checkpoint_button)
	_buttons.add_child(MenuKit.button("PAUSE_RESTART_ACT", func() -> void: _stage().restart_stage()))
	_buttons.add_child(MenuKit.button("PAUSE_OPTIONS", _open_options))
	_quit_button = MenuKit.button("PAUSE_QUIT_MAP", func() -> void: _stage().quit_to_menu())
	_buttons.add_child(_quit_button)


func _unhandled_input(event: InputEvent) -> void:
	if _options:
		return  # The options menu handles its own way back.
	if event.is_action_pressed("pause") or (visible and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if visible:
			resume()
		else:
			open()


func open() -> void:
	var stage := _stage()
	if stage == null or not stage.can_pause():
		return
	_checkpoint_button.visible = GameState.checkpoint != ""
	_quit_button.text = "PAUSE_QUIT_MAP" if SaveGame.has_slot() and stage.hub_scene != "" else "PAUSE_QUIT_TITLE"
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MenuKit.focus_first(_buttons)


func resume() -> void:
	visible = false
	get_tree().paused = false
	if get_viewport().get_camera_3d() is PlayerCamera:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


func _open_options() -> void:
	_options = options_scene.instantiate() as Control
	add_child(_options)
	_screen.visible = false  # Hidden behind the options, so the focus can't wander back to it.
	_options.connect("closed", func() -> void:
		_options = null
		_screen.visible = true
		MenuKit.focus_first(_buttons))


func _stage() -> Stage:
	return get_tree().current_scene as Stage
