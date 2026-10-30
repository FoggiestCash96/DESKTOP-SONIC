class_name AirState
extends PlayerState
## Airborne: gravity, classic air drag near the top of a jump, air control up to top speed, and a
## shorter jump when jump is let go early. Lands on any surface gentle enough to stand on.

var jumped := false  ## Left the ground by jumping, which also curls the player into a ball.
var rising := false  ## Still rising from that jump, so letting go of jump can cut it short.


func label() -> String:
	return "AIR  (jump)" if jumped else "AIR"


func enter(previous: PlayerState) -> void:
	var was_curled := previous == player.roll_state or previous == player.spin_dash_state
	player.set_ball(jumped or was_curled)
	player.ground_normal = Vector3.UP
	player.up_direction = Vector3.UP


func exit() -> void:
	jumped = false
	rising = false


func tick(delta: float) -> void:
	var physics := player.physics
	if player.wants_jump() and player.coyote_jump_ready():
		player.jump()
		return
	var horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var vertical := player.velocity.y
	if rising:
		if not player.jump_held:
			vertical = PlayerMotion.release_cap(vertical, physics)
		if vertical <= 0.0:
			rising = false
	if physics.air_drag:
		horizontal = PlayerMotion.air_drag(horizontal, vertical, delta)
	horizontal = PlayerMotion.air_velocity(horizontal, player.wish, physics, delta)
	vertical = PlayerMotion.fall_speed(vertical, physics, delta)
	player.velocity = horizontal + Vector3.UP * vertical
	player.turn_upright(delta)


func after_move(_delta: float) -> void:
	if player.is_on_floor() and player.velocity.dot(player.get_floor_normal()) <= 0.0:
		player.land()
