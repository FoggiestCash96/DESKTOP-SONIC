class_name DriftState
extends PlayerState
## Drifting: sliding round a corner at speed with drift held, turning to one side (`side`) at up
## to drift_turn_rate however fast the player goes. Friction still slows them, though the boost
## holds its speed. It ends when drift is let go, the player is too slow, or they jump.

var side := 1.0  ## 1 drifting right, -1 left.


func label() -> String:
	return "DRIFT  (%s)" % ("right" if side > 0.0 else "left")


func enter(_previous: PlayerState) -> void:
	player.set_ball(false)
	Sfx.play(&"skid")


func tick(delta: float) -> void:
	var physics := player.physics
	if not player.drift_held or player.ground_speed < physics.drift_min_speed:
		player.change_state(player.ground_state)
		player.move_on_ground()
		return
	if player.wants_jump():
		player.jump()
		return
	player.apply_slope(physics.slp, delta)
	player.ground_speed = maxf(player.ground_speed - physics.frc * delta, 0.0)
	if player.boosting:
		player.ground_speed = maxf(player.ground_speed, physics.boost_speed)
	var right := player.heading.cross(player.ground_normal)
	var into := 0.0
	if right.length_squared() > 1e-6:
		into = player.wish.dot(right.normalized()) * side
	player.heading = PlayerMotion.drift_heading(player.heading, player.ground_normal, side, into, physics, delta)
	player.move_on_ground()


func after_move(_delta: float) -> void:
	player.follow_ground()
