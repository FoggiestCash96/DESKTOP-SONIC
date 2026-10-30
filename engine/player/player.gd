class_name Player
extends CharacterBody3D
## Kinematic player controller: classic momentum on the ground, free 3D velocity in the air.
## Milestone 2 covers flat ground; slopes and surface alignment arrive in Milestone 3.
## Movement input is relative to the active camera, and all tuning lives in `physics`.

enum State { GROUND, AIR }

const OVERLAY_LABELS: Array[String] = ["State", "Speed", "Velocity", "Heading", "Position"]

@export var physics: PlayerPhysics = preload("res://engine/player/player_physics.tres")
@export var kill_height: float = -50.0  ## Falling below this height (m) respawns the player.

var state: State = State.AIR
var ground_speed := 0.0  ## Speed along the ground (m/s).
var heading := Vector3.FORWARD  ## Direction of travel on the ground, as a unit vector.

var _spawn: Transform3D
var _jumping := false  # Rising from a jump, so letting go of jump can cut it short.
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0

@onready var _visual: Node3D = %Visual


func _ready() -> void:
	_spawn = global_transform
	heading = _flat(-global_basis.z, Vector3.FORWARD)
	DebugOverlay.watch("State", func() -> String: return "%s%s" % [State.keys()[state], "  (jumping)" if _jumping else ""])
	DebugOverlay.watch("Speed", func() -> String: return "%.2f m/s  (top %.2f)" % [ground_speed, physics.top])
	DebugOverlay.watch("Velocity", func() -> String: return "horizontal %.2f  vertical %.2f m/s" % [Vector2(velocity.x, velocity.z).length(), velocity.y])
	DebugOverlay.watch("Heading", func() -> String: return "%.0f°  (turn rate %.0f°/s)" % [rad_to_deg(atan2(-heading.x, -heading.z)), rad_to_deg(PlayerMotion.turn_rate(ground_speed, physics))])
	DebugOverlay.watch("Position", func() -> String: return "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z])


func _exit_tree() -> void:
	for label in OVERLAY_LABELS:
		DebugOverlay.unwatch(label)


func _physics_process(delta: float) -> void:
	var jump_pressed := Input.is_action_just_pressed("jump")
	if jump_pressed:
		_jump_buffer_timer = physics.jump_buffer_time
	var wants_jump := jump_pressed or _jump_buffer_timer > 0.0
	var wish := _wish_direction()

	if state == State.GROUND:
		_ground_tick(wish, wants_jump, delta)
	else:
		_air_tick(wish, wants_jump, delta)
	move_and_slide()
	_after_move()

	_visual.global_basis = Basis.looking_at(heading, Vector3.UP)
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if global_position.y < kill_height:
		respawn()


## Puts the player back where it started, standing still.
func respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	ground_speed = 0.0
	heading = _flat(-_spawn.basis.z, Vector3.FORWARD)
	state = State.AIR
	_jumping = false
	reset_physics_interpolation()


func _ground_tick(wish: Vector3, wants_jump: bool, delta: float) -> void:
	var strength := wish.length()
	if strength > 0.0:
		var wish_dir := wish / strength
		if ground_speed > 0.0 and rad_to_deg(heading.angle_to(wish_dir)) > physics.brake_angle:
			ground_speed = PlayerMotion.brake_speed(ground_speed, physics, delta)
			if ground_speed < 0.0:  # Braked to a stop: turn around.
				heading = wish_dir
				ground_speed = -ground_speed
		else:
			if ground_speed > 0.0:
				var max_turn := PlayerMotion.turn_rate(ground_speed, physics) * delta
				heading = PlayerMotion.turn_toward(heading, wish_dir, Vector3.UP, max_turn)
			else:
				heading = wish_dir  # From a standstill, face the input straight away.
			ground_speed = PlayerMotion.run_speed(ground_speed, strength, physics, delta)
	else:
		ground_speed = PlayerMotion.run_speed(ground_speed, 0.0, physics, delta)
	ground_speed = minf(ground_speed, physics.max_ground_speed)
	velocity = heading * ground_speed
	if wants_jump:
		_jump()


func _air_tick(wish: Vector3, wants_jump: bool, delta: float) -> void:
	if wants_jump and _coyote_timer > 0.0:
		_jump()  # Just ran off a ledge, so a jump still counts.
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var vertical := velocity.y
	if _jumping:
		if not Input.is_action_pressed("jump"):
			vertical = PlayerMotion.release_cap(vertical, physics)
		if vertical <= 0.0:
			_jumping = false
	if physics.air_drag:
		horizontal = PlayerMotion.air_drag(horizontal, vertical, delta)
	horizontal = PlayerMotion.air_velocity(horizontal, wish, physics, delta)
	vertical = PlayerMotion.fall_speed(vertical, physics, delta)
	velocity = horizontal + Vector3.UP * vertical


func _jump() -> void:
	velocity.y = physics.jmp
	state = State.AIR
	_jumping = true
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func _after_move() -> void:
	if state == State.GROUND:
		if is_on_floor():
			_slide_along_walls()
		else:
			state = State.AIR  # Ran off a ledge.
			_coyote_timer = physics.coyote_time
	elif is_on_floor() and velocity.y <= 0.0:
		_land()


func _land() -> void:
	state = State.GROUND
	_jumping = false
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	ground_speed = minf(horizontal.length(), physics.max_ground_speed)
	heading = _flat(horizontal, heading)
	velocity.y = 0.0


## Running into a wall removes the part of the ground speed that points into it, so a head-on
## hit stops the player and a glancing one slides along the wall.
func _slide_along_walls() -> void:
	if not is_on_wall():
		return
	var normal := _flat(get_wall_normal(), Vector3.ZERO)
	var into := heading.dot(normal)
	if into >= 0.0:
		return
	var slide := (heading - normal * into) * ground_speed
	ground_speed = slide.length()
	heading = _flat(slide, heading)


## The direction the player is asking to move in on the ground plane, relative to the active
## camera. Its length (0 to 1) is how far the stick is pushed.
func _wish_direction() -> Vector3:
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if stick == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var view := camera.global_basis if camera else global_basis
	var forward := _flat(-view.z, Vector3.FORWARD)
	var right := _flat(view.x, Vector3.RIGHT)
	return (right * stick.x - forward * stick.y).limit_length(1.0)


## `v` flattened onto the horizontal plane and normalized, or `fallback` if it has no horizontal part.
static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length_squared() > 1e-6 else fallback
