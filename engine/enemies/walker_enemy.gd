class_name WalkerEnemy
extends Enemy
## An enemy that walks the ground. It patrols back and forth along its own X axis, `patrol_distance`
## either side of home. On noticing a player it turns to face them and rears up (notice_time), then
## charges at where they were, up to `charge_distance`. After the charge it stands stunned for a
## moment, then patrols back home. It follows the ground below it and stops at edges and walls.

const WORLD_MASK := 1
const STEP_UP := 0.6  ## Highest step it walks up (m).
const EDGE_DROP := 1.2  ## Deepest drop it walks down; anything deeper is an edge (m).
const WALL_HEIGHT := 0.5  ## Height of the ray that looks for walls ahead (m).

@export var patrol_distance: float = 4.0  ## How far either side of home it patrols (m). 0 stands still.
@export var patrol_speed: float = 2.0  ## (m/s)
@export var charge_speed: float = 9.0  ## (m/s)
@export var charge_distance: float = 8.0  ## Longest charge (m).
@export var body_radius: float = 0.8  ## How close it gets to a wall (m).
@export var turn_speed: float = 6.0  ## How fast it turns (radians per second).
@export var sideways: bool = true  ## Patrols facing ahead and stepping sideways, as a crab does. Off, it faces the way it walks.

var _axis := Vector3.RIGHT
var _home_yaw := 0.0
var _patrol_sign := 1.0
var _charge_direction := Vector3.FORWARD
var _charged := 0.0


func _ready() -> void:
	super()
	_axis = Vector3(global_basis.x.x, 0.0, global_basis.x.z).normalized()
	_home_yaw = rotation.y


func _patrol(delta: float) -> void:
	if patrol_distance <= 0.0:
		return
	var goal := home + _axis * (_patrol_sign * patrol_distance)
	var to_goal := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if to_goal.length() < 0.1 or not _walk(to_goal.normalized(), patrol_speed, delta):
		_patrol_sign = -_patrol_sign
	if sideways:
		rotation.y = rotate_toward(rotation.y, _home_yaw, turn_speed * delta)
	else:
		_turn_toward(to_goal, turn_speed, delta)


func _notice(delta: float) -> void:
	if target:
		_turn_toward(target.global_position - global_position, turn_speed, delta)


func _enter_mode(new_mode: Mode) -> void:
	if new_mode != Mode.ATTACK:
		return
	_charged = 0.0
	var to_target := target.global_position - global_position if target else -global_basis.z
	to_target.y = 0.0
	_charge_direction = to_target.normalized() if to_target.length_squared() > 1e-4 else -global_basis.z


func _attack(delta: float) -> bool:
	if not _walk(_charge_direction, charge_speed, delta):
		return true
	_charged += charge_speed * delta
	return _charged >= charge_distance


## Steps along `direction` (horizontal, unit length) at `speed`, following the ground. Returns false,
## without moving, at an edge or a wall.
func _walk(direction: Vector3, speed: float, delta: float) -> bool:
	var step := direction * speed * delta
	var space := get_world_3d().direct_space_state
	var eye := global_position + Vector3.UP * WALL_HEIGHT
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + direction * (step.length() + body_radius), WORLD_MASK))
	if not wall.is_empty():
		return false
	var next := global_position + step
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(next + Vector3.UP * STEP_UP, next + Vector3.DOWN * EDGE_DROP, WORLD_MASK))
	if ground.is_empty():
		return false
	global_position = Vector3(next.x, (ground["position"] as Vector3).y, next.z)
	return true
