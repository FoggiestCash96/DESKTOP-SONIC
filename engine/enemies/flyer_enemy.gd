class_name FlyerEnemy
extends Enemy
## A flying enemy. It hovers, bobbing, and drifts back and forth along its own X axis. With `swoops`
## on, it notices a player who comes close, rears back for notice_time, then dives at where they
## were and carries on past, before flying back home while stunned. With `swoops` off it only
## hovers: a stepping stone for homing attack chains.

@export var patrol_distance: float = 0.0  ## How far either side of home it drifts (m). 0 hovers in place.
@export var patrol_speed: float = 1.5  ## (m/s)
@export var bob_height: float = 0.25  ## How far it bobs up and down while hovering (m).
@export var bob_period: float = 1.6  ## Seconds per bob.
@export var swoops: bool = true  ## Dives at players. Off, it only hovers.
@export var swoop_speed: float = 11.0  ## (m/s)
@export var swoop_overshoot: float = 3.0  ## How far past the player's spot the dive carries on (m).
@export var rear_height: float = 0.8  ## How far it rises while rearing back to dive (m).
@export var return_speed: float = 5.0  ## Speed back home after a dive (m/s).
@export var turn_speed: float = 5.0  ## How fast it turns (radians per second).

var _axis := Vector3.RIGHT
var _home_yaw := 0.0
var _patrol_sign := 1.0
var _anchor := Vector3.ZERO  # Where it would be without bobbing.
var _bob_time := 0.0
var _dive_end := Vector3.ZERO


func _ready() -> void:
	super()
	_axis = Vector3(global_basis.x.x, 0.0, global_basis.x.z).normalized()
	_home_yaw = rotation.y
	_anchor = global_position
	if not swoops:
		notice_range = 0.0


func _patrol(delta: float) -> void:
	if patrol_distance > 0.0:
		var goal := home + _axis * (_patrol_sign * patrol_distance)
		if _anchor.distance_to(goal) < 0.05:
			_patrol_sign = -_patrol_sign
		_anchor = _anchor.move_toward(goal, patrol_speed * delta)
	else:
		_anchor = _anchor.move_toward(home, return_speed * delta)
	rotation.y = rotate_toward(rotation.y, _home_yaw, turn_speed * delta)
	_hover(delta)


func _notice(delta: float) -> void:
	_anchor = _anchor.move_toward(home + Vector3.UP * rear_height, rear_height / maxf(notice_time, 0.01) * delta)
	if target:
		_turn_toward(target.global_position - global_position, turn_speed, delta)
	_hover(delta)


func _enter_mode(new_mode: Mode) -> void:
	if new_mode != Mode.ATTACK:
		return
	var aim := target.ball_center() if target else global_position - global_basis.z * 4.0
	var dive := aim - global_position
	if dive.length_squared() < 1e-4:
		dive = -global_basis.z
	_dive_end = aim + dive.normalized() * swoop_overshoot


func _attack(delta: float) -> bool:
	global_position = global_position.move_toward(_dive_end, swoop_speed * delta)
	_turn_toward(_dive_end - global_position, turn_speed * 2.0, delta)
	return global_position.distance_to(_dive_end) < 0.05


func _stunned(delta: float) -> void:
	global_position = global_position.move_toward(home, return_speed * delta)
	_turn_toward(home - global_position, turn_speed, delta)
	_anchor = global_position
	_bob_time = 0.0


func _hover(delta: float) -> void:
	_bob_time += delta
	var bob := sin(_bob_time * TAU / maxf(bob_period, 0.01)) * bob_height
	global_position = _anchor + Vector3.UP * bob
