extends "res://tests/test_suite.gd"
## Remappable controls in engine/systems/input_bindings.gd.


func after_each() -> void:
	InputBindings.apply({})  # Back to the project's bindings for the tests that follow.


func test_events_survive_the_settings_file() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_RIGHT_SHOULDER
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 0.8
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_XBUTTON1
	for event: InputEvent in [key, button, trigger, mouse]:
		var back := InputBindings.from_dict(InputBindings.to_dict(event))
		assert_true(back != null and back.is_match(event), "%s" % event)
	assert_true(InputBindings.from_dict({"type": "key", "code": 0}) == null, "no key")
	assert_true(InputBindings.from_dict({"type": "nonsense"}) == null, "an unknown kind")


func test_keyboard_and_controller_bindings_are_told_apart() -> void:
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	assert_true(InputBindings.is_keyboard(InputEventKey.new()) and InputBindings.is_keyboard(InputEventMouseButton.new()))
	assert_true(InputBindings.is_controller(InputEventJoypadButton.new()) and InputBindings.is_controller(trigger))
	assert_false(InputBindings.is_controller(stick), "sticks aren't bindings")
	assert_false(InputBindings.has_controller_binding(&"move_forward"), "movement stays on the stick")
	assert_true(InputBindings.has_controller_binding(&"jump"))
	assert_eq(InputBindings.describe(trigger), "LT")


func test_rebinding_replaces_only_that_kind_of_binding() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	InputBindings.rebind(&"jump", key)
	var keys := InputMap.action_get_events(&"jump").filter(func(event: InputEvent) -> bool: return InputBindings.is_keyboard(event))
	assert_eq(keys.size(), 1, "one keyboard binding")
	assert_true((keys[0] as InputEvent).is_match(key), "and it's the new one")
	assert_true(InputBindings.current(&"jump", false) != null, "the controller binding stays")


func test_saved_overrides_apply_and_reset() -> void:
	var space := InputBindings.current(&"jump", true)
	InputBindings.apply({"jump": {"keyboard": {"type": "key", "code": KEY_J}, "controller": {"type": "joy_button", "button": JOY_BUTTON_Y}}})
	assert_eq(InputBindings.describe(InputBindings.current(&"jump", false)), "Y")
	assert_true(InputBindings.current(&"jump", true).is_match(InputBindings.from_dict({"type": "key", "code": KEY_J})))
	InputBindings.apply({})
	assert_true(InputBindings.current(&"jump", true).is_match(space), "an empty set of overrides puts the defaults back")
