class_name SpinDashState
extends PlayerState
## Crouched and revving in place: each jump press adds charge, which slowly bleeds away. Letting
## go of crouch launches a roll at the classic spin dash speed for the charge built up.

var charge := 0.0


func label() -> String:
	return "SPIN DASH  (charge %.1f)" % charge


func enter(_previous: PlayerState) -> void:
	charge = 0.0
	player.ground_speed = 0.0
	player.set_ball(true)


func tick(delta: float) -> void:
	var physics := player.physics
	charge = PlayerMotion.decay_charge(charge, delta)
	if player.jump_pressed:
		player.consume_jump()
		charge = minf(charge + physics.spin_dash_charge_per_press, physics.spin_dash_max_charge)
	player.aim()
	if player.crouch_held:
		player.ground_speed = 0.0
	else:
		player.ground_speed = PlayerMotion.spin_dash_speed(charge, physics)
		player.change_state(player.roll_state)
	player.move_on_ground()


func after_move(_delta: float) -> void:
	player.follow_ground()
