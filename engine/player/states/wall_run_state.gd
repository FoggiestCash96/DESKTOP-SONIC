class_name WallRunState
extends PlayerState
## Running along a wall-run strip: on the wall, at the speed the player came in with (the boost
## holds boost_speed), with no gravity. At the strip's end they carry on into the air; jump kicks
## them off it; something in the way knocks them off.

const BLOCKED := 0.3  ## Ending up this far from the strip's line after a move means something got in the way (m).
const FOOT_GAP := 0.05  ## The player's feet run this far off the wall (m).

var strip: WallRunStrip
var offset := 0.0  ## How far along the strip the player is (m).
var direction := 1.0  ## 1 running toward the strip's end, -1 toward its start.


func label() -> String:
	return "WALL RUN"


func enter(_previous: PlayerState) -> void:
	player.set_ball(false)
	Sfx.play(&"wall_cling")


func exit() -> void:
	strip = null


## The way the player is running, as a unit vector.
func motion_direction() -> Vector3:
	return strip.along() * direction


func tick(delta: float) -> void:
	var physics := player.physics
	if not is_instance_valid(strip):
		player.change_state(player.air_state)
		return
	if player.wants_jump():
		player.consume_jump()
		player.leave_wall_run(true)
		return
	if player.boosting:
		player.ground_speed = maxf(player.ground_speed, physics.boost_speed)
	player.ground_speed = minf(player.ground_speed, physics.max_ground_speed)
	offset += direction * player.ground_speed * delta
	if offset < 0.0 or offset > strip.length:
		player.leave_wall_run(false)
		return
	# Stand on the wall first: turning the body moves it a little, and the move must start from there.
	player.heading = motion_direction()
	player.ground_normal = strip.normal()
	player.up_direction = player.ground_normal
	player.stand_on(player.ground_normal, player.heading)
	var target := strip.foot_point(offset, FOOT_GAP)
	player.velocity = (target - player.global_position) / delta


func after_move(_delta: float) -> void:
	if strip and player.global_position.distance_to(strip.foot_point(offset, FOOT_GAP)) > BLOCKED:
		player.leave_wall_run(false)
