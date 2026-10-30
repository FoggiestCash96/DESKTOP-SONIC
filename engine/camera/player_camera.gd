class_name PlayerCamera
extends Camera3D
## The game camera. It orbits the player, swings behind them as they run, aims ahead along their
## motion, widens the field of view with speed, keeps world-up through loops, and never sits inside
## geometry. Camera volumes take over with fixed or side-on views for set pieces and 2.5D sections.
## When the player dies it stops following and watches them fall. At high speed it adds speed lines
## and a radial motion blur (%SpeedEffects). Orbit with the mouse (captured while playing; click to
## recapture) or the camera_* actions; camera_recenter swings the camera behind the player. All
## tuning lives in `settings`.

const COLLISION_MASK := (1 << 0) | (1 << 7)  # world, camera_collision

@export var target: Player
@export var settings: CameraSettings = preload("res://engine/camera/camera_settings.tres")

var _yaw := 0.0  # Free-mode orbit.
var _pitch := 0.0
var _since_manual := INF  # Seconds since the player last moved the camera.
var _recenter_elapsed := INF
var _recenter_from := 0.0
var _volume: CameraVolume
var _blend_elapsed := INF
var _blend_duration := 0.0
var _blend_from := Vector4.ZERO  # Yaw, pitch, distance and field of view when the last blend began.
var _view := Vector4.ZERO  # Yaw, pitch, distance and field of view being shown.
var _arm := 0.0  # Camera distance after walls are taken into account.
var _aim_ahead := Vector3.ZERO
var _input_yaw := 0.0
var _input_held := false  # The stick has been held since the camera last switched views.
var _probe := PhysicsShapeQueryParameters3D.new()
var _speed_lines := 0.0  # Strength of the speed effects, smoothed.
var _blur := 0.0

@onready var _effects: ColorRect = %SpeedEffects


func _ready() -> void:
	# Moved every rendered frame rather than every physics tick, so interpolation would only add lag.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var sphere := SphereShape3D.new()
	sphere.radius = settings.collision_radius
	_probe.shape = sphere
	_probe.collision_mask = COLLISION_MASK
	_pitch = deg_to_rad(settings.default_pitch)
	if target:
		_yaw = CameraMath.yaw_facing(target.horizontal_heading())
		var exclude: Array[RID] = [target.get_rid()]
		_probe.exclude = exclude
	_view = Vector4(_yaw, _pitch, settings.distance, settings.fov_rest)
	_input_yaw = _yaw
	_arm = settings.distance
	fov = settings.fov_rest
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	DebugOverlay.watch("Camera", _describe)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DebugOverlay.unwatch("Camera")


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= deg_to_rad(motion.relative.x * settings.mouse_sensitivity)
		_pitch -= deg_to_rad(motion.relative.y * settings.mouse_sensitivity)
		_since_manual = 0.0
		return

	var button := event as InputEventMouseButton
	if button and button.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if target == null:
		return
	_update_speed_effects(delta)
	if target.is_dead():
		_watch_fall()
		return
	_read_camera_input(delta)
	_update_volume()
	_view = _blend(_goal_view(delta), delta)
	_update_input_yaw()
	_place(delta)


## The yaw that movement input is relative to. Usually the camera's own yaw, but when a camera
## volume switches the view while the stick is held, it stays on the old yaw until the stick is let
## go, so running straight into a side-view section doesn't suddenly turn the player.
func input_yaw() -> float:
	return _input_yaw


func _read_camera_input(delta: float) -> void:
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look != Vector2.ZERO:
		_yaw -= look.x * deg_to_rad(settings.look_speed) * delta
		_pitch -= look.y * deg_to_rad(settings.look_speed) * delta
		_since_manual = 0.0
	else:
		_since_manual += delta
	_yaw = wrapf(_yaw, -PI, PI)
	_pitch = clampf(_pitch, deg_to_rad(settings.min_pitch), deg_to_rad(settings.max_pitch))
	if Input.is_action_just_pressed("camera_recenter"):
		_recenter_elapsed = 0.0
		_recenter_from = _yaw


## Switches to the highest-priority volume around the player, or back to free mode, and starts
## blending from the view on screen.
func _update_volume() -> void:
	var feet := target.get_global_transform_interpolated().origin
	var best: CameraVolume = null
	for node in get_tree().get_nodes_in_group(CameraVolume.GROUP):
		var volume := node as CameraVolume
		if volume and volume.contains(feet) and (best == null or volume.priority > best.priority):
			best = volume
	if best == _volume:
		return
	var leaving := _volume
	_volume = best
	_blend_from = _view
	_blend_elapsed = 0.0
	_blend_duration = best.blend_time if best else leaving.blend_time
	_input_held = _stick_held()
	if best == null:
		# Back to free mode: carry on from the view the volume left the camera in.
		_yaw = _view.x
		_pitch = _view.y


func _goal_view(delta: float) -> Vector4:
	var speed_fov := CameraMath.speed_fov(target.velocity.length(), target.physics.top, settings.fov_rest, settings.fov_fast)
	if _volume:
		var volume_fov := _volume.fov if _volume.fov > 0.0 else speed_fov
		return Vector4(_volume.view_yaw(), deg_to_rad(_volume.pitch_degrees), _volume.distance, volume_fov)
	_follow(delta)
	return Vector4(_yaw, _pitch, settings.distance, speed_fov)


## Free mode: camera_recenter swings behind the player at once. Otherwise, a while after the
## player last moved the camera, it eases round behind them as they run, faster the faster they go.
## It leaves them alone when they run at the camera, so they can come back toward it.
func _follow(delta: float) -> void:
	var behind := CameraMath.yaw_facing(target.horizontal_heading())
	if _recenter_elapsed < settings.recenter_time:
		_recenter_elapsed += delta
		_yaw = lerp_angle(_recenter_from, behind, CameraMath.blend_weight(_recenter_elapsed, settings.recenter_time))
		return
	var flat_speed := Vector2(target.velocity.x, target.velocity.z).length()
	if _since_manual < settings.auto_follow_delay or flat_speed < settings.auto_follow_min_speed:
		return
	if rad_to_deg(absf(wrapf(behind - _yaw, -PI, PI))) > settings.auto_follow_max_angle:
		return
	var rate := deg_to_rad(settings.auto_follow_speed) * clampf(flat_speed / target.physics.top, 0.0, 1.0) * delta
	_yaw = wrapf(CameraMath.approach_angle(_yaw, behind, rate), -PI, PI)
	_pitch = move_toward(_pitch, deg_to_rad(settings.default_pitch), rate * 0.5)


func _blend(goal: Vector4, delta: float) -> Vector4:
	if _blend_elapsed >= _blend_duration:
		return goal
	_blend_elapsed += delta
	var weight := CameraMath.blend_weight(_blend_elapsed, _blend_duration)
	return Vector4(lerp_angle(_blend_from.x, goal.x, weight), lerpf(_blend_from.y, goal.y, weight), lerpf(_blend_from.z, goal.z, weight), lerpf(_blend_from.w, goal.w, weight))


func _update_input_yaw() -> void:
	if not _stick_held():
		_input_held = false
	if not _input_held:
		_input_yaw = _view.x


func _place(delta: float) -> void:
	var pivot := target.get_global_transform_interpolated().origin + Vector3.UP * settings.height
	var ahead := CameraMath.look_ahead(target.velocity, settings.look_ahead_time, settings.look_ahead_max)
	if _volume and _volume.side_view:
		var path := _volume.global_basis.x.normalized()
		ahead = path * ahead.dot(path)
	_aim_ahead = _aim_ahead.lerp(ahead, CameraMath.smoothing(settings.look_ahead_smoothing, delta))

	var offset := CameraMath.orbit_offset(_view.x, _view.y, _view.z)
	var clear := offset.length() if _volume and not _volume.avoid_walls else _clear_distance(pivot, offset)
	_arm = clear if clear < _arm else move_toward(_arm, clear, settings.ease_out_speed * delta)
	global_position = pivot + offset.normalized() * _arm
	target.set_model_visible(_arm >= settings.hide_player_distance)

	var aim := pivot + _aim_ahead - global_position
	if aim.length_squared() > 1e-4 and absf(aim.normalized().dot(Vector3.UP)) < 0.999:
		look_at(global_position + aim, Vector3.UP)
	fov = lerpf(fov, _view.w, CameraMath.smoothing(settings.fov_smoothing, delta))


## Speed lines and motion blur grow with the player's speed, and switch off entirely when both are
## at nothing, so they cost nothing at normal speeds.
func _update_speed_effects(delta: float) -> void:
	var speed := target.velocity.length()
	var lines := CameraMath.effect_amount(speed, settings.lines_start, settings.lines_full) if settings.speed_lines and not target.is_dead() else 0.0
	var blur := CameraMath.effect_amount(speed, settings.blur_start, settings.blur_full) * settings.blur_strength if settings.motion_blur and not target.is_dead() else 0.0
	var weight := CameraMath.smoothing(settings.effects_smoothing, delta)
	_speed_lines = lerpf(_speed_lines, lines, weight)
	_blur = lerpf(_blur, blur, weight)
	_effects.visible = _speed_lines > 0.005 or _blur > 0.005
	var material := _effects.material as ShaderMaterial
	material.set_shader_parameter("lines_amount", _speed_lines)
	material.set_shader_parameter("blur_amount", _blur)


## How strong the speed lines and motion blur are right now (0 to 1 each), for tests and tools.
func speed_effects() -> Vector2:
	return Vector2(_speed_lines, _blur)


## While the player is dead the camera stays put and watches them fall.
func _watch_fall() -> void:
	var to := target.get_global_transform_interpolated().origin - global_position
	if to.length_squared() > 1e-4 and absf(to.normalized().dot(Vector3.UP)) < 0.999:
		look_at(global_position + to, Vector3.UP)


## How far from the pivot the camera can sit along `offset` without being inside or behind a wall.
func _clear_distance(pivot: Vector3, offset: Vector3) -> float:
	_probe.transform = Transform3D(Basis(), pivot)
	_probe.motion = offset
	var fractions := get_world_3d().direct_space_state.cast_motion(_probe)
	var safe := fractions[0] if fractions.size() > 0 else 1.0
	if safe >= 1.0:
		return offset.length()
	return maxf(offset.length() * safe - settings.collision_margin, 0.0)


func _stick_held() -> bool:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO


func _describe() -> String:
	var mode := "FREE"
	if _volume:
		mode = "%s %s" % ["SIDE VIEW" if _volume.side_view else "VOLUME", _volume.name]
	return "%s  yaw %.0f°  distance %.1f m  fov %.0f°" % [mode, rad_to_deg(_view.x), _arm, fov]
