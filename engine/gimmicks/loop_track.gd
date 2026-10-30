@tool
class_name LoopTrack
extends Node3D
## A loop-the-loop built from a few numbers, with low curbs along both edges to keep the player on.
## The track starts at this node's origin heading along -Z, climbs a full vertical circle and comes
## back down beside the entry, shifted along +X by `exit_offset` so its two ends don't meet.
## The mesh and collision are generated when the node is ready (in the editor too) and never saved.

@export var radius: float = 4.0:
	set(value):
		radius = value
		_rebuild()
@export var width: float = 4.0:
	set(value):
		width = value
		_rebuild()
@export var exit_offset: float = 5.0:  ## How far the exit is shifted sideways from the entry (m).
	set(value):
		exit_offset = value
		_rebuild()
@export var curb_height: float = 0.6:
	set(value):
		curb_height = value
		_rebuild()
@export_range(8, 512) var segments: int = 96:
	set(value):
		segments = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		_rebuild()

var _generated: Array[Node] = []


func _ready() -> void:
	_build()


## Point on the track's center line `angle` radians around the loop (0 at the entry, TAU at the exit).
static func center_point(angle: float, loop_radius: float, offset: float) -> Vector3:
	return Vector3(offset * angle / TAU, loop_radius - loop_radius * cos(angle), -loop_radius * sin(angle))


## Normal of the track surface `angle` radians around the loop. It points at the loop's middle.
static func surface_normal(angle: float) -> Vector3:
	return Vector3(0.0, cos(angle), sin(angle))


func _rebuild() -> void:
	if is_node_ready():
		_build()


func _build() -> void:
	for node in _generated:
		node.queue_free()
	_generated.clear()

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in segments:
		var angle_a := TAU * i / segments
		var angle_b := TAU * (i + 1) / segments
		var normal_a := surface_normal(angle_a)
		var normal_b := surface_normal(angle_b)
		var side_a := _side(angle_a)
		var side_b := _side(angle_b)
		var center_a := center_point(angle_a, radius, exit_offset)
		var center_b := center_point(angle_b, radius, exit_offset)
		var left_a := center_a - side_a * width * 0.5
		var right_a := center_a + side_a * width * 0.5
		var left_b := center_b - side_b * width * 0.5
		var right_b := center_b + side_b * width * 0.5
		var facing := (normal_a + normal_b).normalized()
		_quad(surface, faces, left_a, right_a, right_b, left_b, facing)
		_quad(surface, faces, left_a, left_b, left_b + normal_b * curb_height, left_a + normal_a * curb_height, side_a)
		_quad(surface, faces, right_a, right_b, right_b + normal_b * curb_height, right_a + normal_a * curb_height, -side_a)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	_add_generated(mesh_instance)

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_mask = 0
	body.add_child(collision)
	_add_generated(body)


func _add_generated(node: Node) -> void:
	add_child(node)
	_generated.append(node)


## Unit vector across the track at `angle`, pointing from its left edge to its right edge.
func _side(angle: float) -> Vector3:
	var tangent := Vector3(exit_offset / TAU, radius * sin(angle), -radius * cos(angle))
	return tangent.cross(surface_normal(angle)).normalized()


## Adds the quad a-b-c-d to the mesh as two-sided triangles, and once to the collision faces.
## `normal` is the side the quad should face.
static func _quad(surface: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	for corners: PackedVector3Array in [PackedVector3Array([a, b, c]), PackedVector3Array([a, c, d])]:
		var triangle := corners
		# Godot treats a triangle as facing (third - first) x (second - first).
		if (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).dot(normal) < 0.0:
			triangle = PackedVector3Array([triangle[0], triangle[2], triangle[1]])
		faces.append_array(triangle)
		for corner in triangle:
			surface.set_normal(normal)
			surface.add_vertex(corner)
		for corner in PackedVector3Array([triangle[0], triangle[2], triangle[1]]):
			surface.set_normal(-normal)
			surface.add_vertex(corner)
