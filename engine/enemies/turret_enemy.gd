class_name TurretEnemy
extends Enemy
## A gun that stays put. Closed, it waits for a player to come close; then it opens up and turns to
## face them (notice_time) and fires `burst` shots at them, `fire_interval` apart, before closing
## for stun_time. Shots (EnemyShot) leave from %Muzzle and fly straight at where the player was.

@export var shot_scene: PackedScene = preload("res://engine/enemies/base/enemy_shot.tscn")
@export var burst: int = 2  ## Shots each time it opens.
@export var fire_interval: float = 0.8  ## Seconds between shots.
@export var shot_speed: float = 8.0  ## (m/s)
@export var turns: bool = true  ## Turns to face the player. Off, it fires straight ahead along -Z.
@export var turn_speed: float = 3.0  ## (radians per second)

var _fired := 0

@onready var _muzzle: Node3D = %Muzzle


func _notice(delta: float) -> void:
	_face_target(delta)


func _enter_mode(new_mode: Mode) -> void:
	if new_mode == Mode.ATTACK:
		_fired = 0


func _attack(delta: float) -> bool:
	_face_target(delta)
	if _fired < burst and mode_time >= _fired * fire_interval:
		_fire()
		_fired += 1
	return _fired >= burst and mode_time >= burst * fire_interval


func _fire() -> void:
	var shot := shot_scene.instantiate() as EnemyShot
	shot.speed = shot_speed
	get_parent().add_child(shot)
	shot.global_position = _muzzle.global_position
	if target and turns:
		shot.aim_at(target.ball_center())
	else:
		shot.direction = -_muzzle.global_basis.z.normalized()


func _face_target(delta: float) -> void:
	if turns and target:
		_turn_toward(target.global_position - global_position, turn_speed, delta)
