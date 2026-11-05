@tool
class_name GrindRail
extends Path3D
## A rail to grind along, following this node's curve. A player who lands on it, or runs onto its
## end, grinds along it (GrindState): faster downhill, slower uphill, on into the air off its end.
## Jump leaves it, and a quickstep hops to another rail beside it. It builds its own mesh, a tube
## `radius` thick, in the editor as well as in the game; supports and the like are the stage art's.

const GROUP := "grind_rails"
const STEP := 0.5  ## The mesh follows the curve in steps about this long (m).
const TANGENT_STEP := 0.25  ## Tangents are measured over this much curve either side (m).

@export var radius: float = 0.09:  ## Thickness of the rail (m).
	set(value):
		radius = value
		_build()
@export_range(3, 16) var sides: int = 8:  ## Sides of the tube.
	set(value):
		sides = value
		_build()
@export var material: Material:  ## The rail's look. Empty takes the art bank's "rail".
	set(value):
		material = value
		_build()

var _mesh: MeshInstance3D
var _bounds := AABB()  # The curve's bounds in world space, for a quick check before the exact one.


func _ready() -> void:
	add_to_group(GROUP)
	if not curve_changed.is_connected(_build):
		curve_changed.connect(_build)
	_build()


## Length of the rail along its curve (m).
func length() -> float:
	return curve.get_baked_length() if curve else 0.0


## How far along the rail the point closest to `point` is (m).
func closest_offset(point: Vector3) -> float:
	return curve.get_closest_offset(to_local(point))


## The middle of the rail `offset` metres along it.
func point_at(offset: float) -> Vector3:
	return to_global(curve.sample_baked(clampf(offset, 0.0, length()), true))


## Where a grinding player's feet go, `offset` metres along: on top of the rail.
func top_at(offset: float) -> Vector3:
	return point_at(offset) + Vector3.UP * radius


## The way the rail runs `offset` metres along it, toward its end, as a unit vector.
func tangent_at(offset: float) -> Vector3:
	var ahead := point_at(minf(offset + TANGENT_STEP, length()))
	var behind := point_at(maxf(offset - TANGENT_STEP, 0.0))
	var along := ahead - behind
	return along.normalized() if along.length_squared() > 1e-8 else -global_basis.z


## Whether `point` is within `reach` of the rail's bounds: a cheap test before closest_offset().
func near(point: Vector3, reach: float) -> bool:
	return _bounds.grow(reach).has_point(point)


func _build() -> void:
	if not is_node_ready() or curve == null:
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
	var total := length()
	if total <= 0.0:
		_mesh.mesh = null
		return
	var steps := maxi(1, ceili(total / STEP))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var low := Vector3.INF
	var high := -Vector3.INF
	for i in steps + 1:
		var offset := total * float(i) / float(steps)
		var centre := curve.sample_baked(offset, true)
		var global_centre := to_global(centre)
		low = low.min(global_centre)
		high = high.max(global_centre)
		var along := (curve.sample_baked(minf(offset + TANGENT_STEP, total), true) - curve.sample_baked(maxf(offset - TANGENT_STEP, 0.0), true)).normalized()
		var side := along.cross(Vector3.UP)
		if side.length_squared() < 1e-6:
			side = along.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(along).normalized()
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for k in sides:
			var angle := TAU * float(k) / float(sides)
			var out := side * cos(angle) + up * sin(angle)
			ring.append(centre + out * radius)
			ring_normals.append(out)
		rings.append(ring)
		normals.append(ring_normals)
	var step_length := total / float(steps)
	for i in steps:
		for k in sides:
			var j := (k + 1) % sides
			# Corners as (ring, side). Godot's front faces wind clockwise seen from outside.
			var corners: Array[Vector2i] = [Vector2i(i, k), Vector2i(i + 1, k), Vector2i(i + 1, j), Vector2i(i, k), Vector2i(i + 1, j), Vector2i(i, j)]
			var a := rings[i][k]
			if (rings[i + 1][k] - a).cross(rings[i + 1][j] - a).dot(normals[i][k]) > 0.0:
				corners = [Vector2i(i, k), Vector2i(i + 1, j), Vector2i(i + 1, k), Vector2i(i, k), Vector2i(i, j), Vector2i(i + 1, j)]
			for corner in corners:
				tool.set_normal(normals[corner.x][corner.y])
				tool.set_uv(Vector2(float(corner.y) / float(sides), float(corner.x) * step_length))
				tool.add_vertex(rings[corner.x][corner.y])
	_mesh.mesh = tool.commit()
	var look := material if material else ArtBank.material(&"rail", _default_material())
	_mesh.material_override = look
	_bounds = AABB(low, high - low)


static func _default_material() -> StandardMaterial3D:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.74, 0.78)
	steel.metallic = 0.6
	steel.roughness = 0.35
	return steel
