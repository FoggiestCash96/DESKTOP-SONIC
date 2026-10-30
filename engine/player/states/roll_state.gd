class_name RollState
extends PlayerState
## Rolling in a ball: running input can't speed it up, it steers gently and brakes when pushed
## back, and downhill slopes speed it up far more than they speed up running. It stands up when slow.


func label() -> String:
	return "ROLL"


func enter(_previous: PlayerState) -> void:
	player.set_ball(true)


func tick(delta: float) -> void:
	var physics := player.physics
	var uphill := player.heading.dot(Vector3.UP) > 0.0
	player.apply_slope(physics.slp_roll_up if uphill else physics.slp_roll_down, delta)
	player.roll(delta)
	if player.wants_jump():
		player.jump()
		return
	if player.ground_speed < physics.unroll_speed:
		player.change_state(player.ground_state)
	player.move_on_ground()


func after_move(_delta: float) -> void:
	player.follow_ground()
