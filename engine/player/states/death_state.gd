class_name DeathState
extends PlayerState
## Dead: a hop straight up, then a fall through everything with no control while the stage gets
## ready to restart. Falling out of the world skips the hop.

var hop := true  ## Set before entering: false for a fall out of the world.


func label() -> String:
	return "DEAD"


func enter(_previous: PlayerState) -> void:
	player.set_ball(false)
	player.set_intangible(true)
	player.ground_speed = 0.0
	player.ground_normal = Vector3.UP
	player.up_direction = Vector3.UP
	player.velocity = Vector3.UP * player.physics.death_rise if hop else Vector3.ZERO


func exit() -> void:
	player.set_intangible(false)


func tick(delta: float) -> void:
	player.velocity.y = PlayerMotion.fall_speed(player.velocity.y, player.physics, delta)
