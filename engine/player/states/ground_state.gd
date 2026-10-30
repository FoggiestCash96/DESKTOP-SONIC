class_name GroundState
extends PlayerState
## On foot: running, braking and turning, or crouching when still. Holding crouch while moving
## starts a roll, and pressing jump while crouched starts a spin dash.

var crouching := false


func label() -> String:
	return "GROUND  (crouching)" if crouching else "GROUND"


func enter(_previous: PlayerState) -> void:
	player.set_ball(false)
	crouching = false


func tick(delta: float) -> void:
	var physics := player.physics
	if player.ground_speed > 0.0 or PlayerMotion.slope_beats_friction(player.ground_normal, physics):
		player.apply_slope(physics.slp, delta)
	crouching = player.crouch_held and player.ground_speed < physics.roll_min_speed
	if player.crouch_held and not crouching:
		player.change_state(player.roll_state)
	elif crouching and player.jump_pressed:
		player.consume_jump()
		player.change_state(player.spin_dash_state)
	elif crouching:
		player.coast(delta)
	else:
		player.run(delta)
		if player.wants_jump():
			player.jump()
			return
	player.move_on_ground()


func after_move(_delta: float) -> void:
	player.follow_ground()
