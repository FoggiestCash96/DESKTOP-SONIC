class_name LostRing
extends Ring
## A ring knocked loose by a hit. It flies out, falls and bounces, can be collected again after a
## moment, then flashes and vanishes. Its numbers come from the PlayerPhysics of the player who
## dropped it.

const WORLD_MASK := 1  ## Scattered rings bounce off level geometry only.
const RADIUS := 0.3  ## How far the ring's middle stays from a surface it bounces off (m).
const FLASH_TIME := 1.0  ## Seconds before vanishing that the ring starts to flash.
const FLASH_PERIOD := 0.1

var velocity := Vector3.ZERO
var _physics: PlayerPhysics
var _start := Vector3.ZERO
var _age := 0.0


## Sets the ring up before it enters the tree: it starts at `from`, moving at `launch_velocity`.
func drop(from: Vector3, launch_velocity: Vector3, physics: PlayerPhysics) -> void:
	_start = from
	velocity = launch_velocity
	_physics = physics


func _ready() -> void:
	super()
	collectable = false
	global_position = _start
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_age += delta
	var left := _physics.lost_ring_lifetime - _age
	if left <= 0.0:
		queue_free()
		return
	visible = left > FLASH_TIME or fmod(left, FLASH_PERIOD) > FLASH_PERIOD * 0.5
	if not collectable and _age >= _physics.lost_ring_pickup_delay:
		collectable = true
		for body in get_overlapping_bodies():  # Already touching a player: collect it now.
			_on_body_entered(body)
	if _target and _fly_to_target(delta):
		return
	_fall(delta)


## Gravity, and a bounce off any level geometry in the way.
func _fall(delta: float) -> void:
	velocity.y -= _physics.lost_ring_gravity * delta
	var motion := velocity * delta
	if motion.length_squared() < 1e-12:
		return
	var from := global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + motion + motion.normalized() * RADIUS, WORLD_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = from + motion
		return
	var normal: Vector3 = hit["normal"]
	var point: Vector3 = hit["position"]
	velocity = GimmickMath.bounce(velocity, normal, _physics.lost_ring_bounce)
	global_position = point + normal * RADIUS
