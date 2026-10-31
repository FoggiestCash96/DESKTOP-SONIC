class_name HomingState
extends PlayerState
## A homing attack: curled up, flying straight at a target at homing_speed and following it as it
## moves. When the attack lands, whatever was hit bounces the player off it (Player.rebound_from()
## or Player.bounce_back()). The attack gives up, carrying on through the air, if the target goes
## away or can no longer be hit, or after homing_max_time.

var target: HomingTarget
var _elapsed := 0.0


func label() -> String:
	return "HOMING"


func enter(_previous: PlayerState) -> void:
	_elapsed = 0.0
	player.set_ball(true)
	player.ground_normal = Vector3.UP
	player.up_direction = Vector3.UP


func exit() -> void:
	target = null


func tick(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(target) or not target.enabled or _elapsed > player.physics.homing_max_time:
		_give_up()
		return
	var offset := target.global_position - player.ball_center()
	if offset.length_squared() > 1e-6:
		player.velocity = offset.normalized() * player.physics.homing_speed
	player.turn_upright(delta)


## Back to falling, still curled, no faster than an air dash.
func _give_up() -> void:
	player.velocity = player.velocity.limit_length(player.physics.air_dash_speed)
	player.air_state.jumped = true
	player.change_state(player.air_state)
