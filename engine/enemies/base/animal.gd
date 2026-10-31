class_name Animal
extends Node3D
## A little animal freed from a destroyed enemy. It pops up out of the wreck, then hops away along
## the ground, away from the player, and is gone after `lifetime`. It passes through everything and
## only looks for the ground to hop on.

const WORLD_MASK := 1

@export var pop_speed: float = 6.0  ## Upward speed as it pops out (m/s).
@export var hop_speed: float = 4.5  ## Upward speed of each hop (m/s).
@export var run_speed: float = 3.5  ## Speed along the ground while hopping (m/s).
@export var gravity: float = 20.0  ## (m/s²)
@export var lifetime: float = 5.0  ## Seconds before it's gone.

var velocity := Vector3.ZERO
var _direction := Vector3.FORWARD
var _age := 0.0


func _ready() -> void:
	velocity = Vector3.UP * pop_speed
	var angle := randf() * TAU
	_direction = Vector3(sin(angle), 0.0, cos(angle))


## Hops away from `point`, such as the player who freed it.
func flee_from(point: Vector3) -> void:
	var away := Vector3(global_position.x - point.x, 0.0, global_position.z - point.z)
	if away.length_squared() > 1e-4:
		_direction = away.normalized()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	velocity.y -= gravity * delta
	var next := global_position + velocity * delta
	if velocity.y < 0.0:
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, next, WORLD_MASK)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit["position"]
			velocity = Vector3.UP * hop_speed + _direction * run_speed
			look_at(global_position + _direction, Vector3.UP)
			return
	global_position = next
