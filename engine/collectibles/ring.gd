class_name Ring
extends Area3D
## A ring: touching it adds one to the player's count. A player with the ring magnet pulls nearby
## rings in. Every ring spins in step on the GPU (ring.gdshader), so a level full of them costs no
## script time until one starts to move.

var collectable := true  ## Scattered rings start out of reach for a moment.
var _target: Player  # The player whose magnet is pulling this ring in.


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _fly_to_target(delta):
		set_physics_process(false)


## Starts the ring flying to `player`, whose magnet has caught it.
func attract(player: Player) -> void:
	if collectable and _target == null:
		_target = player
		set_physics_process(true)


## Moves the ring toward the player pulling it in, always faster than they are moving. Returns
## false, and lets go, once there is no such player.
func _fly_to_target(delta: float) -> bool:
	if not is_instance_valid(_target) or _target.is_dead():
		_target = null
		return false
	var goal := _target.global_position + _target.global_basis.y * 0.5
	var step := (_target.velocity.length() + _target.physics.magnet_pull_speed) * delta
	global_position += (goal - global_position).limit_length(step)
	return true


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if collectable and player:
		collectable = false
		player.collect_rings(1)
		queue_free()
