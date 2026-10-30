extends Camera3D
## Free-flying developer camera for looking around greybox scenes.
## Move with move_*, rise with jump, sink with crouch, hold boost to go faster.
## Look with the mouse (captured while the scene runs; click to recapture) or the camera_* actions.

@export var move_speed: float = 12.0  ## Metres per second.
@export var boost_multiplier: float = 4.0
@export var look_speed_degrees: float = 120.0  ## Stick and arrow-key look speed, degrees per second.
@export var mouse_sensitivity: float = 0.15  ## Degrees per pixel of mouse motion.

var _yaw: float
var _pitch: float


func _ready() -> void:
	# Moved every rendered frame rather than every physics tick, so interpolation would only add lag.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_yaw = rotation.y
	_pitch = rotation.x
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
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	_yaw -= look.x * deg_to_rad(look_speed_degrees) * delta
	_pitch -= look.y * deg_to_rad(look_speed_degrees) * delta
	_pitch = clampf(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	rotation = Vector3(_pitch, _yaw, 0.0)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical := Input.get_axis("crouch", "jump")
	var direction := basis * Vector3(input.x, 0.0, input.y) + Vector3.UP * vertical
	var speed := move_speed * (boost_multiplier if Input.is_action_pressed("boost") else 1.0)
	position += direction.limit_length(1.0) * speed * delta
