class_name LeaperEnemy
extends Enemy
## An enemy that leaps out of hiding, as a fish leaps from water. It waits out of sight below its
## spot, leaps up in an arc `leap_height` high and `leap_distance` along its -Z axis over
## `leap_time`, drops back out of sight, and rests for `rest_time` before the next leap, which goes
## back the other way. Only while out of hiding can it be hit, or hurt anyone. It keeps to its own
## timetable rather than noticing players; `start_delay` staggers neighbouring leapers.

@export var leap_height: float = 4.0  ## (m)
@export var leap_distance: float = 0.0  ## How far along its -Z axis each leap carries it (m). 0 leaps straight up and down.
@export var leap_time: float = 1.2  ## Seconds each leap takes.
@export var rest_time: float = 1.5  ## Seconds out of sight between leaps.
@export var start_delay: float = 0.0  ## Extra seconds before the first leap.
@export var hide_depth: float = 1.0  ## How far below its spot it waits (m).

var _leaps := 0
var _forward := Vector3.FORWARD
var _from := Vector3.ZERO


func _ready() -> void:
	notice_range = 0.0
	stun_time = 0.0
	_forward = -global_basis.z.normalized()
	super()
	mode_time = -start_delay


func _enter_mode(new_mode: Mode) -> void:
	var out := new_mode == Mode.ATTACK
	model.visible = out
	hitbox.monitoring = out
	homing_target.enabled = out
	if new_mode == Mode.PATROL:
		global_position = _from + Vector3.DOWN * hide_depth if _leaps > 0 else home + Vector3.DOWN * hide_depth
	elif out:
		_from = global_position + Vector3.UP * hide_depth


func _patrol(_delta: float) -> void:
	if mode_time >= rest_time:
		_set_mode(Mode.NOTICE)


func _attack(_delta: float) -> bool:
	var u := clampf(mode_time / maxf(leap_time, 0.01), 0.0, 1.0)
	var direction := _forward * (1.0 if _leaps % 2 == 0 else -1.0)
	global_position = _from + direction * (leap_distance * u) + Vector3.UP * EnemyMath.leap_height(u, leap_height)
	model.rotation = Vector3(EnemyMath.leap_pitch(u, leap_height, leap_distance), 0.0 if _leaps % 2 == 0 else PI, 0.0)
	if u < 1.0:
		return false
	_leaps += 1
	_from = global_position
	return true
