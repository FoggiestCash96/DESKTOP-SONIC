@tool
class_name MovingPlatform
extends AnimatableBody3D
## A solid platform that moves: back and forth by `travel` (in its own space), easing in and out
## and waiting at each end, or floating on a WaterVolume (`float_on`) as its tide rises and falls.
## Players ride it, and one it squeezes against the level is crushed (Player). Its origin is the
## middle of its top, so place it where the top should be; a floating platform never sinks below
## that, so at low tide it rests where it was placed. It draws itself from its `size`: a stone
## slab, or a raft of floating logs.

const GROUP := "crushers"  ## Things that move and can crush a player.

enum Look { SLAB, LOGS }

@export var size := Vector3(4.0, 0.6, 4.0):  ## Width (X), thickness (Y) and length (Z) of the platform (m).
	set(value):
		size = value
		_update_shape()
@export var travel := Vector3.ZERO  ## How far it moves from where it starts, in its own space (m). Zero stays put.
@export var travel_time: float = 3.0  ## Seconds each way.
@export var pause_time: float = 1.0  ## Seconds it waits at each end.
@export var start_time: float = 0.0  ## Seconds into its cycle when the stage starts, to stagger neighbours.
@export var float_on: WaterVolume  ## Water it floats on: its top stays `float_height` above the surface as the tide rises and falls, never lower than where it was placed.
@export var float_height: float = 0.3  ## How far its top floats above the water (m).
@export var look: Look = Look.SLAB:  ## What it looks like.
	set(value):
		look = value
		_update_shape()

var _start: Transform3D
var _time := 0.0
var _shape: CollisionShape3D
var _mesh: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	_update_shape()
	if Engine.is_editor_hint():
		return
	sync_to_physics = true
	_start = transform
	_time = start_time
	# Move before anything rides or tests against it this tick.
	process_physics_priority = -2


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var next := _start
	if travel != Vector3.ZERO:
		next.origin += _start.basis * travel * GimmickMath.platform_travel(_time, travel_time, pause_time)
	if float_on:
		var parent := get_parent_node_3d()
		var world := parent.global_transform * next.origin if parent else next.origin
		world.y = maxf(float_on.surface_height(world) + float_height, world.y)
		next.origin = parent.global_transform.affine_inverse() * world if parent else world
	transform = next


func _update_shape() -> void:
	if not is_node_ready():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		add_child(_shape)
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position = Vector3(0.0, -size.y * 0.5, 0.0)
	if _mesh:
		_mesh.queue_free()
	_mesh = PlatformLook.build(look == Look.LOGS, size)
	add_child(_mesh)
