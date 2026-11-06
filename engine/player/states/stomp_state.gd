class_name StompState
extends PlayerState
## A stomp: curled up and slamming straight down at stomp_speed. Like any curled-up player it
## destroys badniks and breaks item monitors, but it doesn't bounce off them: it carries on down
## and lands, without speed but for what a slope gives.


func label() -> String:
	return "STOMP"


func enter(_previous: PlayerState) -> void:
	player.set_ball(true)
	player.ground_normal = Vector3.UP
	player.up_direction = Vector3.UP
	player.velocity = Vector3.DOWN * player.physics.stomp_speed
	Sfx.play(&"stomp")


func tick(delta: float) -> void:
	player.velocity = Vector3.DOWN * player.physics.stomp_speed
	player.turn_upright(delta, false)


func after_move(_delta: float) -> void:
	if player.is_on_floor():
		Sfx.play(&"stomp_land")
		player.land()
