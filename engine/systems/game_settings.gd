extends Node
## The player's settings for the whole game, kept apart from the save slots so they apply from the
## title screen on: video, audio volumes, the camera, the speed effects, accessibility and controls.
## Autoloaded as GameSettings. Stored in `path`, and applied at start-up and on apply(). The camera,
## player and stages read the gameplay settings as they need them.

signal changed

const GAME_SPEEDS: Array[float] = [1.0, 0.9, 0.8, 0.7]  ## Game speed choices: slower gives more time to react.
const HUD_SCALES: Array[float] = [1.0, 1.25, 1.5]
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144]  ## 0 is no limit.
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Voice"]
const MIN_RENDER_SCALE := 0.5
const MIN_CAMERA_SENSITIVITY := 0.25
const MAX_CAMERA_SENSITIVITY := 2.0
## The settings file's sections and the settings stored in each (the volumes and controls have their own).
const SECTIONS: Dictionary[String, Array] = {
	"video": ["fullscreen", "vsync", "render_scale", "fps_limit"],
	"camera": ["camera_sensitivity", "invert_x", "invert_y"],
	"effects": ["speed_lines", "motion_blur", "screen_shake"],
	"accessibility": ["game_speed", "assist", "hud_scale"],
}

var path := "user://settings.cfg"  ## Tests point this somewhere else.

@export_group("Video")
@export var fullscreen := false
@export var vsync := true
@export var render_scale := 1.0  ## Resolution of the 3D view, from MIN_RENDER_SCALE to 1: lower runs faster on slower graphics cards.
@export var fps_limit := 0  ## One of FPS_LIMITS.

@export_group("Audio")
@export var volumes: Dictionary[StringName, float] = {&"Master": 1.0, &"Music": 0.8, &"SFX": 0.8, &"Voice": 0.8}  ## 0 to 1 for each of BUSES.

@export_group("Camera")
@export var camera_sensitivity := 1.0  ## Multiplies how fast the mouse and the right stick turn the camera.
@export var invert_x := false
@export var invert_y := false

@export_group("Effects")
@export var speed_lines := true
@export var motion_blur := true
@export var screen_shake := true

@export_group("Accessibility")
@export var game_speed := 1.0  ## One of GAME_SPEEDS.
@export var assist := false  ## Hits never hurt, and pits put the player back on solid ground instead of costing a life.
@export var hud_scale := 1.0  ## One of HUD_SCALES.

@export_group("Controls")
@export var bindings: Dictionary = {}  ## Remapped controls: action -> {"keyboard": event, "controller": event}, as InputBindings stores them.


func _ready() -> void:
	load_settings()
	apply()


## Reads the settings file. Anything missing or out of range keeps or falls back to its default.
func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for section in SECTIONS:
		for key: String in SECTIONS[section]:
			var current: Variant = get(key)
			var stored: Variant = file.get_value(section, key, current)
			if typeof(stored) == typeof(current) or (current is float and stored is int):
				set(key, stored)
	for bus in BUSES:
		volumes[bus] = clampf(float(file.get_value("audio", String(bus).to_lower(), volumes.get(bus, 1.0))), 0.0, 1.0)
	var stored_bindings: Variant = file.get_value("controls", "bindings", {})
	bindings = stored_bindings if stored_bindings is Dictionary else {}
	sanitize()


func save_settings() -> void:
	var file := ConfigFile.new()
	for section in SECTIONS:
		for key: String in SECTIONS[section]:
			file.set_value(section, key, get(key))
	for bus in BUSES:
		file.set_value("audio", String(bus).to_lower(), volumes.get(bus, 1.0))
	file.set_value("controls", "bindings", bindings)
	var error := file.save(path)
	if error != OK:
		push_error("Can't save %s: %s" % [path, error_string(error)])


## Puts every setting back in range: the nearest allowed choice, or clamped.
func sanitize() -> void:
	render_scale = clampf(render_scale, MIN_RENDER_SCALE, 1.0)
	camera_sensitivity = clampf(camera_sensitivity, MIN_CAMERA_SENSITIVITY, MAX_CAMERA_SENSITIVITY)
	game_speed = nearest(GAME_SPEEDS, game_speed)
	hud_scale = nearest(HUD_SCALES, hud_scale)
	if fps_limit not in FPS_LIMITS:
		fps_limit = 0


## Applies the settings that act on the whole game (window, frame rate, 3D resolution, volumes and
## controls) and tells everything else that settings changed.
func apply() -> void:
	sanitize()
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and not (fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN):
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_limit
	get_tree().root.scaling_3d_scale = render_scale
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			var volume := clampf(float(volumes.get(bus, 1.0)), 0.0, 1.0)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
			AudioServer.set_bus_mute(index, volume <= 0.001)
	InputBindings.apply(bindings)
	changed.emit()


## Remaps `action` to `event` (InputBindings.rebind()) and remembers it.
func rebind(action: StringName, event: InputEvent) -> void:
	InputBindings.rebind(action, event)
	var kinds: Dictionary = bindings.get_or_add(String(action), {})
	kinds["keyboard" if InputBindings.is_keyboard(event) else "controller"] = InputBindings.to_dict(event)


## Puts every control back to its default binding.
func reset_bindings() -> void:
	bindings = {}
	InputBindings.apply(bindings)


## The choice in `choices` closest to `value`.
static func nearest(choices: Array[float], value: float) -> float:
	var best := choices[0]
	for choice in choices:
		if absf(choice - value) < absf(best - value):
			best = choice
	return best
