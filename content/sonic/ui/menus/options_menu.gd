extends Control
## The options: video, audio, camera, controls and accessibility, one tab each (LB and RB, or Q and
## E, switch tabs). Changes apply at once and are saved when the menu closes. Opened from the title
## screen and the pause menu, and works while the game is paused. To remap a control, pick its
## keyboard or controller binding and press the new key or button (Esc cancels).

signal closed

const CAPTURE_TIMEOUT := 6.0  ## Seconds to wait for a new binding before giving up.
const PERCENT_FORMAT := "%d%%"

var _capture_action: StringName = &""
var _capture_keyboard := true
var _capture_button: Button
var _capture_time := 0.0
var _binding_buttons: Dictionary[String, Button] = {}  # "action/keyboard" or "action/controller" -> its button.

@onready var _tabs: TabContainer = %Tabs
@onready var _back: Button = %Back


func _ready() -> void:
	_build_video(_tab("OPT_VIDEO"))
	_build_audio(_tab("OPT_AUDIO"))
	_build_camera(_tab("OPT_CAMERA"))
	_build_controls(_tab("OPT_CONTROLS"))
	_build_accessibility(_tab("OPT_ACCESSIBILITY"))
	_back.pressed.connect(close)
	MenuKit.focus_first(_tabs.get_current_tab_control())


func _process(delta: float) -> void:
	if _capture_action != &"":
		_capture_time += delta
		if _capture_time > CAPTURE_TIMEOUT:
			_end_capture()


## Saves the settings and closes the menu.
func close() -> void:
	GameSettings.save_settings()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _capture_action != &"":
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("quickstep_left") or event.is_action_pressed("quickstep_right"):
		get_viewport().set_input_as_handled()
		var step := -1 if event.is_action_pressed("quickstep_left") else 1
		_tabs.current_tab = wrapi(_tabs.current_tab + step, 0, _tabs.get_tab_count())
		MenuKit.focus_first(_tabs.get_current_tab_control())


## Catches the next key or button while a binding is being changed.
func _input(event: InputEvent) -> void:
	if _capture_action == &"" or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key and key.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_end_capture()
		return
	var motion := event as InputEventJoypadMotion
	if motion and absf(motion.axis_value) < InputBindings.TRIGGER_THRESHOLD:
		return
	var wanted := InputBindings.is_keyboard(event) if _capture_keyboard else InputBindings.is_controller(event)
	if not wanted:
		return
	get_viewport().set_input_as_handled()
	var bound := InputBindings.from_dict(InputBindings.to_dict(event))
	GameSettings.rebind(_capture_action, bound)
	_end_capture()


# --- Tabs --------------------------------------------------------------------------------------

func _build_video(rows: VBoxContainer) -> void:
	_toggle(rows, "OPT_FULLSCREEN", "fullscreen")
	_toggle(rows, "OPT_VSYNC", "vsync")
	_slider(rows, "OPT_RENDER_SCALE", func() -> float: return GameSettings.render_scale * 100.0,
		func(value: float) -> void: GameSettings.render_scale = value / 100.0, GameSettings.MIN_RENDER_SCALE * 100.0, 100.0, 5.0)
	var limits: PackedStringArray = []
	for limit in GameSettings.FPS_LIMITS:
		limits.append(tr("OPT_UNLIMITED") if limit == 0 else str(limit))
	_choice(rows, "OPT_FPS_LIMIT", limits, func() -> int: return GameSettings.FPS_LIMITS.find(GameSettings.fps_limit),
		func(index: int) -> void: GameSettings.fps_limit = GameSettings.FPS_LIMITS[index])


func _build_audio(rows: VBoxContainer) -> void:
	var labels: Dictionary[StringName, String] = {&"Master": "OPT_MASTER", &"Music": "OPT_MUSIC", &"SFX": "OPT_SFX", &"Voice": "OPT_VOICE"}
	for bus in GameSettings.BUSES:
		_slider(rows, labels[bus], func() -> float: return float(GameSettings.volumes.get(bus, 1.0)) * 100.0,
			func(value: float) -> void: GameSettings.volumes[bus] = value / 100.0, 0.0, 100.0, 5.0)


func _build_camera(rows: VBoxContainer) -> void:
	_slider(rows, "OPT_SENSITIVITY", func() -> float: return GameSettings.camera_sensitivity * 100.0,
		func(value: float) -> void: GameSettings.camera_sensitivity = value / 100.0,
		GameSettings.MIN_CAMERA_SENSITIVITY * 100.0, GameSettings.MAX_CAMERA_SENSITIVITY * 100.0, 5.0)
	_toggle(rows, "OPT_INVERT_X", "invert_x")
	_toggle(rows, "OPT_INVERT_Y", "invert_y")
	_toggle(rows, "OPT_SPEED_LINES", "speed_lines")
	_toggle(rows, "OPT_MOTION_BLUR", "motion_blur")
	_toggle(rows, "OPT_SCREEN_SHAKE", "screen_shake")


func _build_controls(rows: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_child(_row_label(""))
	header.add_child(_column_label("OPT_KEYBOARD"))
	header.add_child(_column_label("OPT_CONTROLLER"))
	rows.add_child(header)
	for action in InputBindings.ACTIONS:
		var row := HBoxContainer.new()
		row.add_child(_row_label("ACTION_" + String(action).to_upper()))
		row.add_child(_binding_button(action, true))
		row.add_child(_binding_button(action, false))
		rows.add_child(row)
	rows.add_child(MenuKit.button("OPT_RESET_CONTROLS", func() -> void:
		GameSettings.reset_bindings()
		_refresh_bindings()))


func _build_accessibility(rows: VBoxContainer) -> void:
	var speeds: PackedStringArray = []
	for speed in GameSettings.GAME_SPEEDS:
		speeds.append(PERCENT_FORMAT % roundi(speed * 100.0))
	_choice(rows, "OPT_GAME_SPEED", speeds, func() -> int: return GameSettings.GAME_SPEEDS.find(GameSettings.game_speed),
		func(index: int) -> void: GameSettings.game_speed = GameSettings.GAME_SPEEDS[index])
	_toggle(rows, "OPT_ASSIST", "assist")
	var sizes: PackedStringArray = []
	for factor in GameSettings.HUD_SCALES:
		sizes.append(PERCENT_FORMAT % roundi(factor * 100.0))
	_choice(rows, "OPT_HUD_SIZE", sizes, func() -> int: return GameSettings.HUD_SCALES.find(GameSettings.hud_scale),
		func(index: int) -> void: GameSettings.hud_scale = GameSettings.HUD_SCALES[index])
	var note := MenuKit.label("OPT_ASSIST_NOTE", 24, Color(1, 1, 1, 0.75))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(900, 0)
	rows.add_child(note)


# --- Rows --------------------------------------------------------------------------------------

func _tab(title_key: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr(title_key))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	return rows


func _row_label(text: String) -> Label:
	var made := MenuKit.label(text, 30)
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


func _column_label(text: String) -> Label:
	var made := MenuKit.label(text, 24, MenuKit.YELLOW)
	made.custom_minimum_size = Vector2(300, 0)
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return made


func _toggle(rows: VBoxContainer, text: String, property: String) -> void:
	var row := HBoxContainer.new()
	row.add_child(_row_label(text))
	var check := CheckButton.new()
	check.button_pressed = bool(GameSettings.get(property))
	check.toggled.connect(func(on: bool) -> void:
		GameSettings.set(property, on)
		GameSettings.apply())
	row.add_child(check)
	rows.add_child(row)


func _slider(rows: VBoxContainer, text: String, getter: Callable, setter: Callable, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_child(_row_label(text))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(360, 40)
	slider.focus_mode = Control.FOCUS_ALL
	slider.value = float(getter.call())
	var shown := MenuKit.label(PERCENT_FORMAT % roundi(slider.value), 28)
	shown.custom_minimum_size = Vector2(110, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value)
		shown.text = PERCENT_FORMAT % roundi(value)
		GameSettings.apply())
	row.add_child(slider)
	row.add_child(shown)
	rows.add_child(row)


func _choice(rows: VBoxContainer, text: String, choices: PackedStringArray, getter: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_child(_row_label(text))
	var options := OptionButton.new()
	options.custom_minimum_size = Vector2(300, 0)
	for choice in choices:
		options.add_item(choice)
	options.select(maxi(int(getter.call()), 0))
	options.item_selected.connect(func(index: int) -> void:
		setter.call(index)
		GameSettings.apply())
	row.add_child(options)
	rows.add_child(row)


func _binding_button(action: StringName, keyboard: bool) -> Button:
	var made := Button.new()
	made.custom_minimum_size = Vector2(300, 0)
	made.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if keyboard or InputBindings.has_controller_binding(action):
		made.pressed.connect(func() -> void: _start_capture(action, keyboard, made))
	else:
		made.disabled = true
	_binding_buttons["%s/%s" % [action, "keyboard" if keyboard else "controller"]] = made
	_show_binding(action, keyboard, made)
	return made


func _show_binding(action: StringName, keyboard: bool, button: Button) -> void:
	if not keyboard and not InputBindings.has_controller_binding(action):
		button.text = tr("OPT_STICK")
	else:
		button.text = InputBindings.describe(InputBindings.current(action, keyboard))


func _refresh_bindings() -> void:
	for key in _binding_buttons:
		var parts := key.split("/")
		_show_binding(StringName(parts[0]), parts[1] == "keyboard", _binding_buttons[key])


func _start_capture(action: StringName, keyboard: bool, button: Button) -> void:
	_capture_action = action
	_capture_keyboard = keyboard
	_capture_button = button
	_capture_time = 0.0
	button.text = tr("OPT_PRESS_KEY" if keyboard else "OPT_PRESS_BUTTON")


func _end_capture() -> void:
	var button := _capture_button
	_capture_action = &""
	_capture_button = null
	_refresh_bindings()
	if button:
		button.grab_focus()
