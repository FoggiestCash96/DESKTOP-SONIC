extends Node3D
## Basic third-person camera that orbits and follows a target. A stand-in for testing movement
## until the full camera (look-ahead, speed FOV, camera volumes) arrives in Milestone 4.
## Orbit with the mouse (captured while the scene runs; click to recapture) or the camera_*
## actions. camera_recenter swings the camera behind the target's direction of travel.

@export var target: Node3D
@export var height: float = 1.0  ## Height above the target's origin that the camera orbits (m).
@export var distance: float = 6.0  ## Preferred distance from the target (m). Walls pull the camera closer.
@export var start_pitch_degrees: float = -15.0  ## Negative looks down at the target.
@export var min_pitch_degrees: float = -75.0
@export var max_pitch_degrees: float = 20.0
@export var look_speed_degrees: float = 150.0  ## Stick and arrow-key orbit speed, degrees per second.
@export var mouse_sensitivity: float = 0.15  ## Degrees per pixel of mouse motion.

var _yaw := 0.0
var _pitch := 0.0

@onready var _arm: SpringArm3D = %Arm


func _ready() -> void:
	# Moved every rendered frame rather than every physics tick, so interpolation would only add lag.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_arm.spring_length = distance
	_pitch = deg_to_rad(start_pitch_degrees)
	if target:
		_yaw = _yaw_behind(_target_forward())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= deg_to_rad(motion.relative.x * mouse_sensitivity)
		_pitch -= deg_to_rad(motion.relative.y * mouse_sensitivity)
		return

	var button := event as InputEventMouseButton
	if button and button.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if target == null:
		return
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	_yaw -= look.x * deg_to_rad(look_speed_degrees) * delta
	_pitch -= look.y * deg_to_rad(look_speed_degrees) * delta
	_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	if Input.is_action_just_pressed("camera_recenter"):
		_yaw = _yaw_behind(_target_forward())
	global_position = target.get_global_transform_interpolated().origin + Vector3.UP * height
	global_rotation = Vector3(_pitch, _yaw, 0.0)


## The target's direction of travel: a player's heading, otherwise the way it faces.
func _target_forward() -> Vector3:
	var player := target as Player
	if player:
		return player.heading
	return -target.global_basis.z


## The yaw that puts the camera behind something travelling in `forward`.
static func _yaw_behind(forward: Vector3) -> float:
	return atan2(-forward.x, -forward.z)
