extends "res://tests/test_suite.gd"
## Guards the project-wide settings the physics design depends on (docs/DESIGN.md, section 3).

## Actions every scene can rely on existing.
const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_forward", &"move_back",
	&"camera_left", &"camera_right", &"camera_up", &"camera_down",
	&"jump", &"boost", &"crouch", &"drift", &"quickstep_left", &"quickstep_right",
	&"special", &"camera_recenter", &"pause", &"debug_overlay",
]

## Gameplay is controller first, so these need both a keyboard and a controller binding.
const KEYBOARD_AND_CONTROLLER_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_forward", &"move_back",
	&"camera_left", &"camera_right", &"camera_up", &"camera_down",
	&"jump", &"boost", &"crouch", &"drift", &"quickstep_left", &"quickstep_right",
	&"special", &"pause",
]


func test_physics_runs_at_120_hz() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 120)
	assert_eq(Engine.physics_ticks_per_second, 120)


func test_jolt_is_the_3d_physics_engine() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_physics_interpolation_is_on() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_interpolation"), true)


func test_required_input_actions_exist() -> void:
	for action in REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "missing input action '%s'" % action)


func test_gameplay_actions_have_keyboard_and_controller_bindings() -> void:
	for action in KEYBOARD_AND_CONTROLLER_ACTIONS:
		if not InputMap.has_action(action):
			continue  # Reported by test_required_input_actions_exist.
		var has_keyboard := false
		var has_controller := false
		for event in InputMap.action_get_events(action):
			has_keyboard = has_keyboard or event is InputEventKey
			has_controller = has_controller or event is InputEventJoypadButton or event is InputEventJoypadMotion
		assert_true(has_keyboard, "'%s' has no keyboard binding" % action)
		assert_true(has_controller, "'%s' has no controller binding" % action)


func test_main_scene_exists() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(main_scene), "main scene '%s' not found" % main_scene)


func test_debug_overlay_is_autoloaded() -> void:
	assert_true(ProjectSettings.has_setting("autoload/DebugOverlay"), "DebugOverlay autoload missing")


func test_game_state_is_autoloaded() -> void:
	assert_true(ProjectSettings.has_setting("autoload/GameState"), "GameState autoload missing")
