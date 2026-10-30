class_name HurtState
extends PlayerState
## Knocked back by a hit: a short hop away under lighter gravity, with no control. Landing stops
## the player dead, as in the classic games, while the flashing invulnerability carries on.


func label() -> String:
	return "HURT"


func enter(_previous: PlayerState) -> void:
	player.set_ball(false)
	player.ground_normal = Vector3.UP
	player.up_direction = Vector3.UP


func tick(delta: float) -> void:
	var physics := player.physics
	player.velocity.y = maxf(player.velocity.y - physics.hurt_gravity * delta, -physics.max_fall)
	player.turn_upright(delta, false)


func after_move(_delta: float) -> void:
	if player.is_on_floor() and player.velocity.dot(player.get_floor_normal()) <= 0.0:
		player.land()
		if player.state != self:
			player.ground_speed = 0.0
