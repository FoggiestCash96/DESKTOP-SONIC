class_name PeelOutState
extends PlayerState
## Revving a Super Peel Out: standing still with drift held, legs spinning faster and faster. Once
## it has revved for peel_out_time, letting go of drift launches the player running at
## peel_out_speed; letting go sooner stands them back down. The stick aims it meanwhile.

var revved := 0.0  ## Seconds of revving so far.


func label() -> String:
	return "PEEL OUT  (%.0f%%)" % (100.0 * charge())


## How far the rev has got, from 0 to 1 (ready).
func charge() -> float:
	return clampf(revved / maxf(player.physics.peel_out_time, 1e-3), 0.0, 1.0)


func enter(_previous: PlayerState) -> void:
	revved = 0.0
	player.ground_speed = 0.0
	player.set_ball(false)
	Sfx.play(&"peel_out")


func tick(delta: float) -> void:
	var physics := player.physics
	revved += delta
	if player.jump_pressed:
		player.consume_jump()  # Already revving: more presses do nothing.
	player.aim()
	if player.drift_held:
		player.ground_speed = 0.0
	else:
		if charge() >= 1.0:
			player.ground_speed = physics.peel_out_speed
			Sfx.play(&"dash_panel")
		player.change_state(player.ground_state)
	player.move_on_ground()


func after_move(_delta: float) -> void:
	player.follow_ground()
