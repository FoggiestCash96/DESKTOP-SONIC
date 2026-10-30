@tool
class_name TidalWave
extends Node3D
## A surge of water that washes along the ground on a timer. Each wave rushes along this node's
## -Z axis for `reach` metres, carrying the player with it, then drains back as a broader sheet,
## dragging them toward the shore, and rests before the next. The water hugs the ground below it,
## so keep anything that overhangs its path out of the way. In the editor a faint box shows how far
## it reaches.

const PUSH_HEIGHT := 7.0  ## Height of the water's push volume (m)...
const PUSH_BELOW := 4.0  ## ...reaching this far below the water, so slopes and dips stay covered.
const SURFACE_HEIGHT := 0.5  ## Thickness of the water you see (m).
const PROBE_HEIGHT := 30.0  ## How far above and below the water it looks for the ground (m).
const WORLD_MASK := 1

@export var size := Vector2(30.0, 8.0):  ## Width (along X) and depth (along Z) of the water (m).
	set(value):
		size = value
		_update_shape()
@export var reach: float = 80.0:  ## How far each wave washes along -Z (m).
	set(value):
		reach = value
		_update_shape()
@export_range(0.1, 60.0) var surge_time: float = 6.0  ## Seconds to wash all the way up.
@export_range(0.1, 60.0) var backwash_time: float = 5.0  ## Seconds to drain back.
@export_range(0.0, 60.0) var rest_time: float = 2.0  ## Seconds between waves.
@export var start_time: float = 0.0  ## Seconds into its cycle the wave is when the stage starts, to stagger neighbouring waves.
@export var surge_speed: float = 17.0  ## Speed a surge carries the player up to, along -Z (m/s).
@export var surge_push: float = 25.0  ## How hard a surge pushes (m/s²).
@export var backwash_speed: float = 6.0  ## Speed the backwash drags the player back toward the shore at (m/s).
@export var backwash_push: float = 8.0  ## How hard the backwash pulls (m/s²). More than ground friction, so it drags a player standing still; a runner just slows down.
@export var backwash_depth: float = 30.0  ## Depth of the draining sheet (m), deeper than the wave so the pull lasts.

var _time := 0.0
var _push_box: BoxShape3D
var _preview: MeshInstance3D

@onready var _water: Area3D = %Water
@onready var _shape: CollisionShape3D = %Shape
@onready var _surface: MeshInstance3D = %Surface
@onready var _foam: MeshInstance3D = %Foam


func _ready() -> void:
	_update_shape()
	_time = start_time
	# Push before the player moves this tick.
	process_physics_priority = -1
	set_physics_process(not Engine.is_editor_hint())


func _physics_process(delta: float) -> void:
	_time += delta
	var cycle := cycle_now()
	var surging := cycle.y > 0.0
	_place_water(cycle.x * reach, size.y if cycle.y >= 0.0 else backwash_depth)
	if cycle.y == 0.0:
		return
	var direction := -global_basis.z.normalized() * cycle.y
	var speed := surge_speed if surging else backwash_speed
	var amount := (surge_push if surging else backwash_push) * delta
	for body in _water.get_overlapping_bodies():
		var player := body as Player
		if player:
			player.push(direction, speed, amount)


## Where the wave is in its cycle right now, as GimmickMath.wave_cycle() describes.
func cycle_now() -> Vector2:
	return GimmickMath.wave_cycle(_time, surge_time, backwash_time, rest_time)


## Puts the water's front `offset` + size.y metres up its run, `depth` deep (never past the shore),
## resting on the ground and tilted to match it.
func _place_water(offset: float, depth: float) -> void:
	var front_z := -offset - size.y
	var back_z := minf(front_z + depth, 0.0)
	var length := back_z - front_z
	var back := _ground_at(back_z)
	var front := _ground_at(front_z)
	_water.position = Vector3(0.0, (back + front) * 0.5, (front_z + back_z) * 0.5)
	_water.rotation.x = atan2(front - back, length)
	_push_box.size.z = length
	_surface.scale.z = length / size.y
	_foam.position.z = -length * 0.5


## Height of the ground below the point `local_z` along the run, in this node's space.
func _ground_at(local_z: float) -> float:
	var top := to_global(Vector3(0.0, PROBE_HEIGHT, local_z))
	var bottom := to_global(Vector3(0.0, -PROBE_HEIGHT, local_z))
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top, bottom, WORLD_MASK))
	if hit.is_empty():
		return 0.0
	return to_local(hit["position"]).y


func _update_shape() -> void:
	if not is_node_ready():
		return
	# Fresh resources, so resizing one wave doesn't resize every wave sharing the scene's resources.
	_push_box = BoxShape3D.new()
	_push_box.size = Vector3(size.x, PUSH_HEIGHT, size.y)
	_shape.shape = _push_box
	_shape.position = Vector3(0.0, PUSH_HEIGHT * 0.5 - PUSH_BELOW, 0.0)
	var slab := BoxMesh.new()
	slab.size = Vector3(size.x, SURFACE_HEIGHT, size.y)
	_surface.mesh = slab
	_surface.position = Vector3(0.0, SURFACE_HEIGHT * 0.5, 0.0)
	var crest := BoxMesh.new()
	crest.size = Vector3(size.x, SURFACE_HEIGHT * 1.6, 0.8)
	_foam.mesh = crest
	_foam.position = Vector3(0.0, SURFACE_HEIGHT * 0.8, -size.y * 0.5)
	_water.position = Vector3(0.0, 0.0, -size.y * 0.5)  # At the shore until the first tick finds the ground.
	_update_preview()


func _update_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if _preview == null:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.2, 0.6, 1.0, 0.1)
		_preview = MeshInstance3D.new()
		_preview.material_override = material
		_preview.mesh = BoxMesh.new()
		add_child(_preview)
	(_preview.mesh as BoxMesh).size = Vector3(size.x, 1.0, reach + size.y)
	_preview.position = Vector3(0.0, 0.5, -(reach + size.y) * 0.5)
