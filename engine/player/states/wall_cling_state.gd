class_name WallClingState
extends PlayerState
## Clinging to a wall-jump panel: facing it, sliding slowly down for up to wall_cling_time. Jump
## kicks off it (Player.wall_jump()); otherwise the player drops off when the time runs out, when
## crouch is pressed, or when they slide off its bottom, and lands if they reach the floor.

var panel: WallJumpPanel
var _time := 0.0


func label() -> String:
	return "WALL CLING  (%.1f s)" % maxf(player.physics.wall_cling_time - _time, 0.0)


func enter(_previous: PlayerState) -> void:
	_time = 0.0
	player.set_ball(false)
	player.ground_normal = Vector3.UP
	player.up_direction = Vector3.UP
	player.velocity = Vector3.ZERO
	Sfx.play(&"wall_cling")


func exit() -> void:
	panel = null


func tick(delta: float) -> void:
	_time += delta
	if not is_instance_valid(panel):
		_drop()
		return
	var normal := panel.normal()
	if player.wants_jump():
		player.consume_jump()
		player.wall_jump(normal)
		return
	if _time >= player.physics.wall_cling_time or player.crouch_pressed or not panel.holds(player.body_center()):
		_drop()
		return
	# Pressed flat against the panel, facing it, sliding down.
	var against := panel.surface_point(player.global_position) + normal * player.wall_offset()
	var sideways := against - player.global_position
	sideways.y = 0.0
	player.velocity = sideways / delta + Vector3.DOWN * player.physics.wall_cling_slide
	player.heading = Vector3(-normal.x, 0.0, -normal.z).normalized()
	player.turn_upright(delta, false)


func after_move(_delta: float) -> void:
	if player.is_on_floor():
		player.land()


# Lets go of the panel, falling away from it a little.
func _drop() -> void:
	var away := panel.normal() if is_instance_valid(panel) else Vector3.ZERO
	player.velocity = away * 1.5
	player.air_state.jumped = false
	player.air_state.rising = false
	player.change_state(player.air_state)
