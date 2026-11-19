@tool
class_name BreakableWall
extends StaticBody3D
## A wall of loose blocks, or with `as_floor` a floor of them. A player rolling or boosting into the
## wall, at `break_speed` or faster, smashes through without slowing down, and the blocks fly apart.
## A player coming down onto the floor curled up (from a jump, or stomping) or boosting, at
## `break_speed` or faster, breaks through it and falls on down. Anyone else is stopped by it like any wall or floor. It comes
## back when the stage reloads. A wall's origin is the middle of its bottom, a floor's the middle of
## its top (so it sits flush with the ground around it). It is `size` big, built from blocks about
## `block` metres across, and looks like `look`: the art bank's "breakable_<look>" material, the same
## as the ground or cliff it's set in.

const REACH := 1.2  ## It breaks when a player this close is coming at it fast enough (m), before they touch it.
const QUAD: Array[int] = [0, 1, 2, 0, 2, 3]  ## A face's two triangles, as corners.

@export var size := Vector3(4.0, 4.0, 1.0):  ## Width (X), height (Y) and thickness (Z) of a wall; width (X), thickness (Y) and depth (Z) of a floor (m).
	set(value):
		size = value
		_build()
@export var block: float = 1.0:  ## Rough size of the blocks it's built from (m).
	set(value):
		block = value
		_build()
@export var as_floor := false:  ## A floor to break through from above, rather than a wall to smash through.
	set(value):
		as_floor = value
		_build()
@export_enum("rock", "grass", "sand", "sandstone", "cave", "cave_floor", "stone", "stone_floor", "planks", "reef") var look: String = "rock":  ## What it's made of: match the ground or cliff around it.
	set(value):
		look = value
		_build()
@export var break_speed: float = 3.0  ## A player has to be closing on it at least this fast (m/s): rolling or boosting into a wall, coming down curled up or boosting onto a floor.

var broken := false
var _blocks: Array[Transform3D] = []  # Each block: its place, and its size as the basis's scale.
var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _detector: Area3D
var _detector_shape: CollisionShape3D
var _material: Material


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	# Break before the player moves into it this tick.
	process_physics_priority = -1


func _physics_process(_delta: float) -> void:
	if broken or Engine.is_editor_hint():
		return
	for body in _detector.get_overlapping_bodies():
		var player := body as Player
		if player == null:
			continue
		if as_floor:
			# Coming down onto it, curled up or boosting.
			var inverse := global_transform.affine_inverse()
			if player.is_attacking() and GimmickMath.breaks_floor(inverse * player.ball_center(), inverse.basis * player.velocity, size, break_speed):
				smash(player.velocity)
				return
			continue
		if not player.can_smash():
			continue
		var middle := global_position + global_basis.y * size.y * 0.5
		var toward := middle - player.ball_center()
		toward.y = 0.0
		if toward.length_squared() < 1e-6:
			continue
		if GimmickMath.breaks_wall(player.velocity, toward.normalized(), break_speed):
			smash(player.velocity)
			return


## Breaks it, throwing its blocks along `push` (the velocity of what hit it).
func smash(push: Vector3) -> void:
	broken = true
	_shape.disabled = true
	_detector.monitoring = false
	_mesh.visible = false
	Sfx.play_at(&"wall_break", global_position + global_basis.y * (-0.5 if as_floor else 0.5) * size.y)
	var debris := Debris.new()
	get_parent().add_child(debris)
	debris.global_transform = global_transform
	var drive := global_basis.inverse() * push.limit_length(12.0) * 0.6
	for place in _blocks:
		var piece := BoxMesh.new()
		piece.size = place.basis.get_scale()
		var fly := drive + Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 5.0) * (0.3 if as_floor else 1.0), randf_range(-2.5, 2.5))
		debris.add_piece(piece, _material, Transform3D(Basis.IDENTITY, place.origin), fly, Vector3(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)))


func _build() -> void:
	if not is_node_ready():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		add_child(_shape)
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
		_detector = Area3D.new()
		_detector.collision_layer = 0
		_detector.collision_mask = 1 << 1  # players
		_detector_shape = CollisionShape3D.new()
		_detector.add_child(_detector_shape)
		add_child(_detector)
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	# A wall stands on its origin; a floor hangs below it, its top level with the origin.
	var low := Vector3(-size.x * 0.5, -size.y if as_floor else 0.0, -size.z * 0.5)
	_shape.position = low + size * 0.5
	var reach := BoxShape3D.new()
	reach.size = size + Vector3(REACH, REACH * (1.0 if as_floor else 0.5), REACH) * 2.0
	_detector_shape.shape = reach
	_detector_shape.position = _shape.position
	_material = PlatformLook.material(StringName("breakable_" + look))
	_blocks.clear()
	# Courses of blocks, every other course offset by half a block, each block a little different in
	# size: a wall's courses are stacked up (Y) and a floor's laid one behind another (Z), and either
	# is as many blocks thick as it needs. Their faces' UVs are in metres: X along the wall, or along
	# the floor's courses, so the stage's stripes (stripes.gdshader) lie across a floor like a deck's
	# planks; Y up.
	var course_axis := 2 if as_floor else 1
	var depth_axis := 1 if as_floor else 2
	var counts := Vector3i(maxi(1, roundi(size.x / block)), maxi(1, roundi(size.y / block)), maxi(1, roundi(size.z / block)))
	var cell := Vector3(size.x / counts.x, size.y / counts.y, size.z / counts.z)
	var random := RandomNumberGenerator.new()
	random.seed = hash(String(name)) if name != &"" else 1
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for course in counts[course_axis]:
		var shift := 0.5 if course % 2 == 1 and counts.x > 1 else 0.0
		for layer in counts[depth_axis]:
			for column in counts.x + (1 if shift > 0.0 else 0):
				var left := maxf((float(column) - shift) * cell.x, 0.0)
				var right := minf((float(column) + 1.0 - shift) * cell.x, size.x)
				if right - left < 0.1:
					continue
				var centre := low
				centre.x += (left + right) * 0.5
				centre[course_axis] += (float(course) + 0.5) * cell[course_axis]
				centre[depth_axis] += (float(layer) + 0.5) * cell[depth_axis]
				var block_size := cell
				block_size.x = right - left
				block_size *= random.randf_range(0.9, 0.98)
				_blocks.append(Transform3D(Basis.from_scale(block_size), centre))
				_add_box(tool, centre, block_size, random.randf_range(0.82, 1.0), 2 if as_floor else 0)
	tool.generate_normals()
	_mesh.mesh = tool.commit()
	_mesh.material_override = _material


## A block's six faces, shaded `shade`, with UV.x measured along the axis `along` (0 for X, 2 for Z),
## or for the two faces that look along it, along the other way across.
static func _add_box(tool: SurfaceTool, centre: Vector3, box_size: Vector3, shade: float, along: int) -> void:
	var half := box_size * 0.5
	var faces: Array[Basis] = [
		Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK), Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD),
		Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT),
		Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN),
	]
	tool.set_color(Color(shade, shade, shade))
	for face in faces:
		# Each face: its right and up axes, and its outward normal (z); corners clockwise from outside.
		var out := face.z * (half * face.z.abs()).length()
		var right := face.x * (half * face.x.abs()).length()
		var up := face.y * (half * face.y.abs()).length()
		var corners: Array[Vector3] = [centre + out - right - up, centre + out - right + up, centre + out + right + up, centre + out + right - up]
		var axis := along if absf(face.z[along]) < 0.5 else 2 - along
		for index in QUAD:
			tool.set_uv(Vector2(corners[index][axis], corners[index].y))
			tool.add_vertex(corners[index])
