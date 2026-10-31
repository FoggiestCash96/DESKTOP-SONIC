extends "res://tests/test_suite.gd"
## Settings in engine/systems/game_settings.gd, on a fresh copy so the real settings are untouched.

const SETTINGS_SCRIPT := preload("res://engine/systems/game_settings.gd")
const TEST_PATH := "user://test_settings.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func test_settings_snap_back_into_range() -> void:
	var settings := SETTINGS_SCRIPT.new()
	settings.set("game_speed", 0.73)
	settings.set("hud_scale", 9.0)
	settings.set("render_scale", 0.1)
	settings.set("camera_sensitivity", 5.0)
	settings.set("fps_limit", 75)
	settings.call("sanitize")
	assert_almost_eq(float(settings.get("game_speed")), 0.7, 1e-6, "the nearest game speed")
	assert_almost_eq(float(settings.get("hud_scale")), 1.5, 1e-6)
	assert_almost_eq(float(settings.get("render_scale")), 0.5, 1e-6)
	assert_almost_eq(float(settings.get("camera_sensitivity")), 2.0, 1e-6)
	assert_eq(int(settings.get("fps_limit")), 0, "an unknown limit means none")
	settings.free()


func test_settings_survive_the_file() -> void:
	var settings := SETTINGS_SCRIPT.new()
	settings.set("path", TEST_PATH)
	settings.set("assist", true)
	settings.set("game_speed", 0.8)
	settings.set("motion_blur", false)
	(settings.get("volumes") as Dictionary)[&"Music"] = 0.25
	settings.set("bindings", {"jump": {"keyboard": {"type": "key", "code": KEY_J}}})
	settings.call("save_settings")
	var loaded := SETTINGS_SCRIPT.new()
	loaded.set("path", TEST_PATH)
	loaded.call("load_settings")
	assert_true(bool(loaded.get("assist")))
	assert_almost_eq(float(loaded.get("game_speed")), 0.8, 1e-6)
	assert_false(bool(loaded.get("motion_blur")))
	assert_almost_eq(float((loaded.get("volumes") as Dictionary)[&"Music"]), 0.25, 1e-6)
	assert_true((loaded.get("bindings") as Dictionary).has("jump"))
	settings.free()
	loaded.free()
