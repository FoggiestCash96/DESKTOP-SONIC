class_name Player
extends CharacterBody3D
## Kinematic player controller with classic momentum physics: speed along the surface, slopes
## that add and take away speed, walls and loops through surface alignment, rolling and the spin
## dash, and free 3D velocity in the air. Each movement state is a script in engine/player/states/;
## the shared surface handling lives here. Input is relative to the active camera, and all tuning
## lives in `physics`.

const OVERLAY_LABELS: Array[String] = ["State", "Speed", "Velocity", "Surface", "Heading", "Position"]
const NEAR_VERTICAL := 75.0  ## Running off the top of a surface this steep (degrees) launches straight up, as at the lip of a half-pipe.

@export var physics: PlayerPhysics = preload("res://engine/player/player_physics.tres")
@export var kill_height: float = -50.0  ## Falling below this height (m) respawns the player.

var ground_speed := 0.0  ## Speed along the ground (m/s).
var heading := Vector3.FORWARD  ## Direction of travel along the ground, as a unit vector.
var ground_normal := Vector3.UP  ## Normal of the surface underfoot, or straight up in the air.

# Input, read once at the start of every physics tick.
var wish := Vector3.ZERO  ## Camera-relative stick direction on the horizontal plane, length 0 to 1.
var jump_pressed := false
var jump_held := false
var crouch_held := false

var state: PlayerState
var ground_state: GroundState
var roll_state: RollState
var spin_dash_state: SpinDashState
var air_state: AirState

var _spawn: Transform3D
var _control_lock := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _flat_heading := Vector3.FORWARD  # Horizontal direction of travel from before the surface got steep.

@onready var _standing_shape: CollisionShape3D = %StandingShape
@onready var _ball_shape: CollisionShape3D = %BallShape
@onready var _body_mesh: Node3D = %Body
@onready var _ball_mesh: Node3D = %Ball


func _ready() -> void:
	ground_state = GroundState.new(self)
	roll_state = RollState.new(self)
	spin_dash_state = SpinDashState.new(self)
	air_state = AirState.new(self)
	floor_snap_length = physics.snap_length
	floor_max_angle = deg_to_rad(physics.surface_step_angle)
	# The states set velocity themselves; without this a falling body touching an edge would stop dead on it.
	floor_stop_on_slope = false
	_spawn = global_transform
	heading = _flat(-global_basis.z, Vector3.FORWARD)
	_flat_heading = heading
	state = air_state
	state.enter(null)

	DebugOverlay.watch("State", func() -> String: return state.label())
	DebugOverlay.watch("Speed", func() -> String: return "%.2f m/s  (top %.2f)" % [ground_speed, physics.top])
	DebugOverlay.watch("Velocity", func() -> String: return "horizontal %.2f  vertical %.2f m/s" % [Vector2(velocity.x, velocity.z).length(), velocity.y])
	DebugOverlay.watch("Surface", func() -> String: return "%.0f° from flat%s" % [PlayerMotion.steepness(ground_normal), "  (slipping %.2f s)" % _control_lock if _control_lock > 0.0 else ""])
	DebugOverlay.watch("Heading", func() -> String: return "%.0f°  (turn rate %.0f°/s)" % [rad_to_deg(atan2(-horizontal_heading().x, -horizontal_heading().z)), rad_to_deg(PlayerMotion.turn_rate(ground_speed, physics))])
	DebugOverlay.watch("Position", func() -> String: return "%.1f, %.1f, %.1f" % [global_position.x, global_position.y, global_position.z])


func _exit_tree() -> void:
	for label in OVERLAY_LABELS:
		DebugOverlay.unwatch(label)


func _physics_process(delta: float) -> void:
	_read_input()
	state.tick(delta)
	move_and_slide()
	state.after_move(delta)
	_control_lock = maxf(_control_lock - delta, 0.0)
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if global_position.y < kill_height:
		respawn()


## Leaves the current state and enters `next`.
func change_state(next: PlayerState) -> void:
	var previous := state
	previous.exit()
	state = next
	next.enter(previous)


## Puts the player back where it started, standing still.
func respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	ground_speed = 0.0
	heading = _flat(-_spawn.basis.z, Vector3.FORWARD)
	_flat_heading = heading
	_control_lock = 0.0
	change_state(air_state)
	reset_physics_interpolation()


## Direction of travel on the horizontal plane, for cameras: the heading, or on steep surfaces
## the way the player was going before it got steep.
func horizontal_heading() -> Vector3:
	return _flat_heading if _is_steep() else _flat(heading, _flat_heading)


# --- Input --------------------------------------------------------------------------------

func wants_jump() -> bool:
	return jump_pressed or _jump_buffer_timer > 0.0


## Uses up this tick's jump press for something other than jumping, such as charging a spin dash.
func consume_jump() -> void:
	jump_pressed = false
	_jump_buffer_timer = 0.0


func coyote_jump_ready() -> bool:
	return _coyote_timer > 0.0


## The stick as a direction along the current surface, length 0 to 1. On surfaces steeper than
## slip_angle it only speeds up or slows down along the path ("forward" is the way the player was
## going before it got steep), so loops and walls work the same from any camera angle.
func surface_wish() -> Vector3:
	if _control_lock > 0.0 or wish == Vector3.ZERO:
		return Vector3.ZERO
	if _is_steep():
		return heading * wish.dot(_flat_heading)
	var along := PlayerMotion.along_surface(wish, ground_normal)
	if along.length_squared() < 1e-6:
		return Vector3.ZERO
	return along.normalized() * wish.length()


# --- Ground movement, used by the ground states -------------------------------------------

## Classic slope physics: gravity's pull along the surface speeds the player up downhill and slows
## them uphill. Across a slope it also bends their path downhill.
func apply_slope(strength: float, delta: float) -> void:
	var motion := heading * ground_speed + PlayerMotion.downhill(ground_normal) * strength * delta
	ground_speed = motion.length()
	if ground_speed > 1e-4:
		heading = motion / ground_speed
	else:
		ground_speed = 0.0


## Running: speeds up toward the stick, brakes when the stick points back, turns at the
## speed-dependent turn rate, and coasts to a stop without input.
func run(delta: float) -> void:
	var input := surface_wish()
	var strength := input.length()
	if strength <= 0.0:
		coast(delta)
		return
	var direction := input / strength
	if ground_speed > 0.0 and rad_to_deg(heading.angle_to(direction)) > physics.brake_angle:
		ground_speed = PlayerMotion.brake_speed(ground_speed, physics, delta)
		if ground_speed < 0.0:  # Braked to a stop: turn around.
			heading = direction
			ground_speed = -ground_speed
		return
	if ground_speed > 0.0:
		var max_turn := PlayerMotion.turn_rate(ground_speed, physics) * delta
		heading = PlayerMotion.turn_toward(heading, direction, ground_normal, max_turn)
	else:
		heading = direction  # From a standstill, face the stick straight away.
	ground_speed = PlayerMotion.run_speed(ground_speed, strength, physics, delta)


## Slowing down with no input.
func coast(delta: float) -> void:
	ground_speed = PlayerMotion.run_speed(ground_speed, 0.0, physics, delta)


## Rolling: the stick can only steer gently or brake, and roll friction always applies.
func roll(delta: float) -> void:
	var input := surface_wish()
	var braking := false
	if input.length_squared() > 1e-6 and ground_speed > 0.0:
		var direction := input.normalized()
		if rad_to_deg(heading.angle_to(direction)) > physics.brake_angle:
			braking = true
		else:
			var max_turn := PlayerMotion.turn_rate(ground_speed, physics) * physics.roll_turn_factor * delta
			heading = PlayerMotion.turn_toward(heading, direction, ground_normal, max_turn)
	ground_speed = PlayerMotion.roll_speed(ground_speed, braking, physics, delta)


## Turns to face the stick without moving, as when lining up a spin dash.
func aim() -> void:
	var input := surface_wish()
	if input.length_squared() > 1e-6:
		heading = input.normalized()


## Sets this tick's velocity from the ground speed and heading, and stands the body on the surface.
func move_on_ground() -> void:
	ground_speed = minf(ground_speed, physics.max_ground_speed)
	velocity = heading * ground_speed
	up_direction = ground_normal
	_orient(ground_normal, heading, 1.0)


## After a move on the ground: follows the surface underfoot, or leaves it at an edge, or drops off
## an overhang that is too steep for this speed. Starts a slip when too slow on a steep surface.
func follow_ground() -> void:
	if not is_on_floor():
		# move_and_slide() only snaps when the velocity points into the surface, and velocity along
		# a slope rounds either way, so snap explicitly. Crests stay stuck; real edges still let go.
		apply_floor_snap()
	var below := _ground_below() if is_on_floor() else {}
	if below.is_empty():
		# Drop any motion into the surface just left. Off a near-vertical wall that means all motion
		# toward it, so the player goes straight up and falls back in instead of drifting over the edge.
		var away := ground_normal
		if PlayerMotion.steepness(ground_normal) > NEAR_VERTICAL:
			away = _flat(ground_normal, ground_normal)
		velocity -= away * minf(velocity.dot(away), 0.0)
		_coyote_timer = physics.coyote_time
		change_state(air_state)
		return
	ground_normal = below["normal"]
	heading = _on_plane(heading, ground_normal, _any_perpendicular(ground_normal))
	_slide_along_walls()
	if not _is_steep():
		_flat_heading = _flat(heading, _flat_heading)
	if PlayerMotion.falls_off(ground_speed, ground_normal, physics):
		change_state(air_state)
		return
	if _control_lock <= 0.0 and PlayerMotion.slips(ground_speed, ground_normal, physics):
		_control_lock = physics.slip_lock_time


## Jumps away from the surface, or straight up just after running off a ledge.
func jump() -> void:
	var grounded := state != air_state
	if grounded:
		velocity = heading * ground_speed + ground_normal * physics.jmp
	else:
		velocity.y = physics.jmp
		set_ball(true)
	air_state.jumped = true
	air_state.rising = true
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	if grounded:
		change_state(air_state)


## Lands on the floor just touched: the part of the velocity along the surface becomes ground speed.
## Touching only an edge, with no ground under the player's middle, isn't a landing: they slide off.
func land() -> void:
	var below := _ground_below()
	if below.is_empty():
		return
	ground_normal = below["normal"]
	var along := PlayerMotion.along_surface(velocity, ground_normal)
	ground_speed = along.length()
	if ground_speed < 1e-4:
		ground_speed = 0.0
		along = heading
	heading = _on_plane(along, ground_normal, _any_perpendicular(ground_normal))
	_flat_heading = _flat(heading, _flat_heading)
	change_state(ground_state)


# --- Body -----------------------------------------------------------------------------------

## Shows or hides the player's model, as when a wall pushes the camera right up against it.
func set_model_visible(on: bool) -> void:
	(_body_mesh.get_parent() as Node3D).visible = on


## Switches between standing and curled into a ball (rolling, spin dash, jumping).
func set_ball(on: bool) -> void:
	_standing_shape.disabled = on
	_ball_shape.disabled = not on
	_body_mesh.visible = not on
	_ball_mesh.visible = on


## In the air: swings the body back upright and faces the direction of travel.
func turn_upright(delta: float) -> void:
	heading = _flat(velocity, heading)
	var up := global_basis.y.normalized()
	var angle := up.angle_to(Vector3.UP)
	var step := minf(deg_to_rad(physics.upright_speed) * delta / maxf(angle, 1e-6), 1.0)
	_orient(Vector3.UP, heading, step)


## Turns the body toward `up` (all the way when `weight` is 1) and to face `forward`. It pivots on
## the center of the rounded bottom, shared by the standing and ball shapes, so the part touching
## the ground stays put instead of digging into it.
func _orient(up: Vector3, forward: Vector3, weight: float) -> void:
	var pivot_height := _ball_shape.position.y
	var current := global_basis.y.normalized()
	var pivot := global_position + current * pivot_height
	var target := up
	if weight < 1.0:
		var axis := current.cross(up)
		if axis.length_squared() < 1e-6:
			axis = forward.cross(current)  # Exactly upside down: tip over forwards.
		target = current.rotated(axis.normalized(), current.angle_to(up) * weight)
	global_basis = Basis.looking_at(_on_plane(forward, target, _any_perpendicular(target)), target)
	global_position = pivot - target * pivot_height


func _is_steep() -> bool:
	return PlayerMotion.steepness(ground_normal) > physics.slip_angle


## The surface straight below the center of the rounded bottom (along -up_direction), within the
## snap distance, as an intersect_ray() result. Like the classic games' ground sensors it reads the
## face underfoot rather than any edge the body brushes, and it ignores surfaces more than
## surface_step_angle away from the current one, so the player launches off the top of a wall
## instead of wrapping around its edge. Empty if there is no ground below.
func _ground_below() -> Dictionary:
	var radius := _ball_shape.position.y
	var center := global_position + global_basis.y.normalized() * radius
	var reach := center - up_direction * (radius + physics.snap_length)
	var query := PhysicsRayQueryParameters3D.create(center, reach, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return hit
	var normal: Vector3 = hit["normal"]
	if rad_to_deg(normal.angle_to(up_direction)) > physics.surface_step_angle:
		return {}
	return hit


## Running into a wall removes the part of the ground speed that points into it, so a head-on hit
## stops the player and a glancing one slides along the wall.
func _slide_along_walls() -> void:
	if not is_on_wall():
		return
	var normal := _on_plane(get_wall_normal(), ground_normal, Vector3.ZERO)
	var into := heading.dot(normal)
	if into >= 0.0:
		return
	var slide := (heading - normal * into) * ground_speed
	ground_speed = slide.length()
	heading = _on_plane(slide, ground_normal, heading)


func _read_input() -> void:
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	crouch_held = Input.is_action_pressed("crouch")
	if jump_pressed:
		_jump_buffer_timer = physics.jump_buffer_time
	wish = _camera_wish()


## The stick direction on the horizontal plane, relative to the active camera. Its length (0 to 1)
## is how far the stick is pushed. A PlayerCamera says which yaw to use, so a camera volume can
## switch views without turning a player who is holding the stick.
func _camera_wish() -> Vector3:
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if stick == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	var yaw := CameraMath.yaw_facing(-global_basis.z)
	if camera is PlayerCamera:
		yaw = (camera as PlayerCamera).input_yaw()
	elif camera:
		yaw = CameraMath.yaw_facing(-camera.global_basis.z)
	var forward := CameraMath.forward_for_yaw(yaw)
	var right := forward.cross(Vector3.UP)
	return (right * stick.x - forward * stick.y).limit_length(1.0)


## `v` projected onto the plane with normal `n` and normalized, or `fallback` if nothing is left.
static func _on_plane(v: Vector3, n: Vector3, fallback: Vector3) -> Vector3:
	var along := v - n * n.dot(v)
	return along.normalized() if along.length_squared() > 1e-6 else fallback


## `v` flattened onto the horizontal plane and normalized, or `fallback` if it has no horizontal part.
static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	return _on_plane(v, Vector3.UP, fallback)


## Some unit vector perpendicular to `n`.
static func _any_perpendicular(n: Vector3) -> Vector3:
	var other := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	return n.cross(other).normalized()
