class_name LightDashState
extends PlayerState
## The light speed dash: zipping from ring to ring at light_dash_speed, collecting each one, for as
## long as the next is within light_dash_link (Player.find_light_dash_ring()). After the last ring
## the player carries on through the air at light_dash_exit_speed. Anything solid in the way ends
## it there.

const BLOCKED := 0.25  ## Covering less than this share of a tick's distance means something is in the way.

var target: Ring
var _direction := Vector3.ZERO
var _expected := 0.0  # How far this tick's move should go (m).
var _start := Vector3.ZERO


func label() -> String:
	return "LIGHT SPEED DASH"


func enter(_previous: PlayerState) -> void:
	_direction = Vector3.ZERO
	player.set_ball(false)
	player.ground_normal = Vector3.UP
	player.up_direction = Vector3.UP
	Sfx.play(&"light_dash")


func exit() -> void:
	target = null


func tick(delta: float) -> void:
	if not _target_left():
		target = player.find_light_dash_ring(player.body_center(), _direction, player.physics.light_dash_link)
		if target == null:
			_finish()
			return
	# The body's middle goes through each ring, so the ring is touched and collected.
	var offset := target.global_position - player.body_center()
	var step := player.physics.light_dash_speed * delta
	if offset.length_squared() > 1e-6:
		_direction = offset.normalized()
	var move := offset if offset.length() <= step else _direction * step
	player.velocity = move / delta
	_expected = move.length()
	_start = player.global_position
	player.heading = Vector3(_direction.x, 0.0, _direction.z).normalized() if absf(_direction.y) < 0.999 else player.heading
	player.turn_upright(delta, false)


func after_move(_delta: float) -> void:
	if _expected > 1e-3 and player.global_position.distance_to(_start) < _expected * BLOCKED:
		_finish()


# Whether the ring being dashed to is still there to collect.
func _target_left() -> bool:
	return is_instance_valid(target) and target.collectable and not target.is_queued_for_deletion()


func _finish() -> void:
	var direction := _direction if _direction != Vector3.ZERO else player.horizontal_heading()
	player.velocity = direction * player.physics.light_dash_exit_speed
	player.air_state.jumped = false
	player.air_state.rising = false
	player.change_state(player.air_state)
