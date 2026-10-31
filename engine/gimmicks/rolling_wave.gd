class_name RollingWave
extends Node3D
## A single wave crest that rolls along the ground along this node's -Z axis for `reach` metres,
## then sinks away. A player it catches is carried along at push_speed until it sinks; jump it to
## stay clear. It rises from nothing as it starts and sinks back at the end, and hugs the ground
## below it. With `rolling` off it waits for roll(), as when a boss sends it out; with free_when_done
## it frees itself afterwards.

signal finished

const PROBE_HEIGHT := 20.0  ## How far above and below the crest it looks for the ground (m).
const WORLD_MASK := 1

@export var width: float = 30.0  ## (m)
@export var height: float = 1.2  ## (m)
@export var thickness: float = 1.6  ## Front to back (m).
@export var speed: float = 12.0  ## How fast it rolls (m/s).
@export var reach: float = 30.0  ## How far it rolls before sinking away (m).
@export var push_speed: float = 13.0  ## Speed it carries a caught player at, along its way (m/s).
@export var push: float = 200.0  ## How hard it pushes (m/s²): enough to pick a player up to its speed as it passes.
@export var rise_time: float = 0.25  ## Seconds to rise at the start, and to sink at the end.
@export var pushes_players: bool = true  ## Off, it's only for show, as in a cutscene.
@export var rolling: bool = true  ## Rolls as soon as it's ready. Off, it waits for roll().
@export var free_when_done: bool = false

var _travelled := 0.0
var _box: BoxShape3D

@onready var _crest: Area3D = %Crest
@onready var _shape: CollisionShape3D = %Shape
@onready var _water: MeshInstance3D = %Water
@onready var _foam: MeshInstance3D = %Foam


func _ready() -> void:
	_box = BoxShape3D.new()
	_shape.shape = _box
	_set_height(height)
	var slab := BoxMesh.new()
	slab.size = Vector3(width, height, thickness)
	_water.mesh = slab
	var crest := BoxMesh.new()
	crest.size = Vector3(width, 0.3, thickness * 0.5)
	_foam.mesh = crest
	visible = rolling
	_crest.monitoring = rolling and pushes_players
	# Push before the player moves this tick.
	process_physics_priority = -1
	set_physics_process(rolling)


## Sends the wave on its way from this node.
func roll() -> void:
	_travelled = 0.0
	rolling = true
	visible = true
	_crest.monitoring = pushes_players
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_travelled += speed * delta
	if _travelled >= reach:
		rolling = false
		visible = false
		_crest.monitoring = false
		set_physics_process(false)
		finished.emit()
		if free_when_done:
			queue_free()
		return
	var time_left := (reach - _travelled) / maxf(speed, 0.01)
	var grown := clampf(minf(_travelled / maxf(speed, 0.01), time_left) / maxf(rise_time, 0.01), 0.05, 1.0)
	_crest.position = Vector3(0.0, _ground_at(-_travelled), -_travelled)
	_set_height(height * grown)
	if not pushes_players:
		return
	var direction := -global_basis.z.normalized()
	for body in _crest.get_overlapping_bodies():
		var player := body as Player
		if player:
			player.push(direction, push_speed, push * delta)


## Resizes the crest (the physics shape itself, since scaled shapes aren't supported).
func _set_height(crest_height: float) -> void:
	_box.size = Vector3(width, crest_height, thickness)
	_shape.position = Vector3(0.0, crest_height * 0.5, 0.0)
	_water.scale = Vector3(1.0, crest_height / height, 1.0)
	_water.position = Vector3(0.0, crest_height * 0.5, 0.0)
	# White water along the top of the leading face.
	_foam.position = Vector3(0.0, crest_height, -thickness * 0.25)


## Height of the ground below the point `local_z` along the run, in this node's space.
func _ground_at(local_z: float) -> float:
	var top := to_global(Vector3(0.0, PROBE_HEIGHT, local_z))
	var bottom := to_global(Vector3(0.0, -PROBE_HEIGHT, local_z))
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top, bottom, WORLD_MASK))
	if hit.is_empty():
		return 0.0
	return to_local(hit["position"]).y
