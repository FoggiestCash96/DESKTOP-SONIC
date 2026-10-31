class_name InputBindings
extends RefCounted
## Remappable controls. Every gameplay action has one keyboard (or mouse) binding that players can
## change, and the button actions one controller binding (a button, or a trigger); movement and the
## camera stay on the controller's sticks and D-pad. Bindings travel as plain dictionaries, so the
## settings file can store them.

## Actions players can remap, in the order the controls screen lists them.
const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"boost", &"crouch", &"drift",
	&"quickstep_left", &"quickstep_right", &"special", &"camera_up", &"camera_down", &"camera_left",
	&"camera_right", &"camera_recenter", &"pause",
]
## Actions that stay on the controller's sticks and D-pad: only their keyboard binding changes.
const STICK_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"camera_up", &"camera_down", &"camera_left", &"camera_right",
]
const TRIGGER_AXES: Array[int] = [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
const TRIGGER_THRESHOLD := 0.6  ## A trigger pulled this far counts as pressed when rebinding.
const BUTTON_NAMES: Dictionary[int, String] = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "Left stick click",
	JOY_BUTTON_RIGHT_STICK: "Right stick click", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const MOUSE_NAMES: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "Left mouse button", MOUSE_BUTTON_RIGHT: "Right mouse button", MOUSE_BUTTON_MIDDLE: "Middle mouse button",
	MOUSE_BUTTON_XBUTTON1: "Mouse back button", MOUSE_BUTTON_XBUTTON2: "Mouse forward button",
}


## Whether `event` is a keyboard key or mouse button, the kind of binding every action has.
static func is_keyboard(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


## Whether `event` is a controller button or trigger, the kind of binding button actions have.
static func is_controller(event: InputEvent) -> bool:
	var motion := event as InputEventJoypadMotion
	return event is InputEventJoypadButton or (motion != null and motion.axis in TRIGGER_AXES)


## Whether `action` has a controller binding players can change.
static func has_controller_binding(action: StringName) -> bool:
	return action not in STICK_ACTIONS


## `event` as a dictionary for the settings file, or empty for kinds of event that can't be bound.
static func to_dict(event: InputEvent) -> Dictionary:
	var key := event as InputEventKey
	if key:
		return {"type": "key", "code": key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode}
	var mouse := event as InputEventMouseButton
	if mouse:
		return {"type": "mouse", "button": mouse.button_index}
	var button := event as InputEventJoypadButton
	if button:
		return {"type": "joy_button", "button": button.button_index}
	var motion := event as InputEventJoypadMotion
	if motion:
		return {"type": "joy_axis", "axis": motion.axis, "value": signf(motion.axis_value)}
	return {}


## The event a dictionary from to_dict() stands for, or null if it doesn't stand for one.
static func from_dict(data: Dictionary) -> InputEvent:
	match str(data.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data.get("code", KEY_NONE)) as Key
			return key if key.physical_keycode != KEY_NONE else null
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("button", MOUSE_BUTTON_NONE)) as MouseButton
			return mouse if mouse.button_index != MOUSE_BUTTON_NONE else null
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data.get("button", JOY_BUTTON_INVALID)) as JoyButton
			return button if button.button_index != JOY_BUTTON_INVALID else null
		"joy_axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(data.get("axis", JOY_AXIS_INVALID)) as JoyAxis
			motion.axis_value = 1.0 if float(data.get("value", 1.0)) >= 0.0 else -1.0
			return motion if motion.axis != JOY_AXIS_INVALID else null
	return null


## A name for `event` to show players, such as "Space", "A" or "RT".
static func describe(event: InputEvent) -> String:
	if event == null:
		return "None"
	var key := event as InputEventKey
	if key:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		var label := DisplayServer.keyboard_get_label_from_physical(code) if key.physical_keycode != KEY_NONE else KEY_NONE
		return OS.get_keycode_string(label if label != KEY_NONE else code)
	var mouse := event as InputEventMouseButton
	if mouse:
		return MOUSE_NAMES.get(mouse.button_index, "Mouse button %d" % mouse.button_index)
	var button := event as InputEventJoypadButton
	if button:
		return BUTTON_NAMES.get(button.button_index, "Button %d" % button.button_index)
	var motion := event as InputEventJoypadMotion
	if motion:
		match motion.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X:
				return "Left stick right" if motion.axis_value > 0.0 else "Left stick left"
			JOY_AXIS_LEFT_Y:
				return "Left stick down" if motion.axis_value > 0.0 else "Left stick up"
			JOY_AXIS_RIGHT_X:
				return "Right stick right" if motion.axis_value > 0.0 else "Right stick left"
			JOY_AXIS_RIGHT_Y:
				return "Right stick down" if motion.axis_value > 0.0 else "Right stick up"
	return event.as_text()


## The binding of the given kind (`keyboard` or controller) that `action` has now, or null.
static func current(action: StringName, keyboard: bool) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if is_keyboard(event) if keyboard else is_controller(event):
			return event
	return null


## Makes `event` the action's binding of its kind, replacing the one it had.
static func rebind(action: StringName, event: InputEvent) -> void:
	var keyboard := is_keyboard(event)
	for old in InputMap.action_get_events(action):
		if is_keyboard(old) if keyboard else is_controller(old):
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, event)


## Puts every action back to the project's bindings, then applies `overrides`:
## action -> {"keyboard": to_dict() of an event, "controller": to_dict() of an event}.
static func apply(overrides: Dictionary) -> void:
	InputMap.load_from_project_settings()
	for action: Variant in overrides:
		var name := StringName(str(action))
		if not InputMap.has_action(name) or not overrides[action] is Dictionary:
			continue
		var kinds: Dictionary = overrides[action]
		for kind: String in ["keyboard", "controller"]:
			var data: Variant = kinds.get(kind)
			if not data is Dictionary:
				continue
			var event := from_dict(data)
			if event and (is_keyboard(event) if kind == "keyboard" else is_controller(event)):
				rebind(name, event)
