@tool
class_name Spikes
extends Area3D
## A bed of spikes. Touching it hurts the player, and it keeps hurting them while they stay on it
## once the flashing invulnerability from the last hit runs out. `size` sets the footprint; the
## points and collision are generated when the node is ready, in the editor too.

const SPACING := 0.5  ## Distance between spike points (m).
const HEIGHT := 0.5  ## Height of the points (m).
const BASE_HEIGHT := 0.1  ## Thickness of the plate the points stand on (m).

@export var size := Vector2(2.0, 2.0):  ## Footprint along X and Z (m).
	set(value):
		size = value
		_build()

@onready var _shape: CollisionShape3D = %Shape
@onready var _base: MeshInstance3D = %Base
@onready var _points: MultiMeshInstance3D = %Points


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	body_entered.connect(func(_body: Node3D) -> void: set_physics_process(true))
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var touching := false
	for body in get_overlapping_bodies():
		var player := body as Player
		if player:
			touching = true
			player.hurt(global_position)
	if not touching:
		set_physics_process(false)


func _build() -> void:
	if not is_node_ready():
		return
	var shape_size := Vector3(size.x, HEIGHT, size.y)
	var columns := maxi(roundi(size.x / SPACING), 1)
	var rows := maxi(roundi(size.y / SPACING), 1)
	var current := _shape.shape as BoxShape3D
	if current and current.size == shape_size and _points.multimesh.instance_count == columns * rows:
		return  # Already built for this size, as when a saved scene opens: nothing to change.
	# Fresh resources, so resizing one bed doesn't resize every bed sharing the scene's resources.
	var box := BoxShape3D.new()
	box.size = shape_size
	_shape.shape = box
	_shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	var plate := BoxMesh.new()
	plate.size = Vector3(size.x, BASE_HEIGHT, size.y)
	_base.mesh = plate
	_base.position = Vector3(0.0, BASE_HEIGHT * 0.5, 0.0)

	var points := MultiMesh.new()
	points.transform_format = MultiMesh.TRANSFORM_3D
	points.mesh = _points.multimesh.mesh
	points.instance_count = columns * rows
	for i in points.instance_count:
		var column := i % columns
		var row := floori(float(i) / columns)
		var x := (column + 0.5) * size.x / columns - size.x * 0.5
		var z := (row + 0.5) * size.y / rows - size.y * 0.5
		points.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, BASE_HEIGHT + HEIGHT * 0.5, z)))
	_points.multimesh = points
