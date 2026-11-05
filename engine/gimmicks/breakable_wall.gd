@tool
class_name BreakableWall
extends StaticBody3D
## A wall of loose rocks. A player rolling or boosting into it, at `break_speed` or faster, smashes
## through without slowing down, and the rocks fly apart. Anyone else is stopped by it like any
## wall. It comes back when the stage reloads. Its origin is the middle of its bottom; it is `size`
## big, built from blocks about `block` metres across.

const REACH := 1.2  ## It breaks when a player this close is coming at it fast enough (m), before they touch it.
const QUAD: Array[int] = [0, 1, 2, 0, 2, 3]  ## A face's two triangles, as corners.

@export var size := Vector3(4.0, 4.0, 1.0):  ## Width (X), height (Y) and thickness (Z) of the wall (m).
	set(value):
		size = value
		_build()
@export var block: float = 1.0:  ## Rough size of the rocks it's built from (m).
	set(value):
		block = value
		_build()
@export var break_speed: float = 3.0  ## A rolling or boosting player has to be closing on the wall at least this fast (m/s).

var broken := false
var _blocks: Array[Transform3D] = []  # Each rock: its place, and its size as the basis's scale.
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
		if player == null or not player.can_smash():
			continue
		var middle := global_position + global_basis.y * size.y * 0.5
		var toward := middle - player.ball_center()
		toward.y = 0.0
		if toward.length_squared() < 1e-6:
			continue
		if GimmickMath.breaks_wall(player.velocity, toward.normalized(), break_speed):
			smash(player.velocity)
			return


## Breaks the wall, throwing its rocks along `push` (the velocity of what hit it).
func smash(push: Vector3) -> void:
	broken = true
	_shape.disabled = true
	_detector.monitoring = false
	_mesh.visible = false
	Sfx.play_at(&"wall_break", global_position + Vector3.UP * size.y * 0.5)
	var debris := Debris.new()
	get_parent().add_child(debris)
	debris.global_transform = global_transform
	var drive := global_basis.inverse() * push.limit_length(12.0) * 0.6
	for place in _blocks:
		var piece := BoxMesh.new()
		piece.size = place.basis.get_scale()
		var fly := drive + Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 5.0), randf_range(-2.5, 2.5))
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
	_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	var reach := BoxShape3D.new()
	reach.size = size + Vector3(REACH, REACH * 0.5, REACH) * 2.0
	_detector_shape.shape = reach
	_detector_shape.position = _shape.position
	_material = PlatformLook.material(&"breakable_rock")
	_blocks.clear()
	# Rows of rocks, every other row offset by half a rock, each a little different in size.
	var columns := maxi(1, roundi(size.x / block))
	var rows := maxi(1, roundi(size.y / block))
	var layers := maxi(1, roundi(size.z / block))
	var cell := Vector3(size.x / columns, size.y / rows, size.z / layers)
	var random := RandomNumberGenerator.new()
	random.seed = hash(String(name)) if name != &"" else 1
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows:
		var shift := 0.5 if row % 2 == 1 and columns > 1 else 0.0
		for layer in layers:
			for column in columns + (1 if shift > 0.0 else 0):
				var left := maxf((float(column) - shift) * cell.x, 0.0)
				var right := minf((float(column) + 1.0 - shift) * cell.x, size.x)
				if right - left < 0.1:
					continue
				var rock_size := Vector3(right - left, cell.y, cell.z) * random.randf_range(0.9, 0.98)
				var centre := Vector3(-size.x * 0.5 + (left + right) * 0.5, (float(row) + 0.5) * cell.y, -size.z * 0.5 + (float(layer) + 0.5) * cell.z)
				_blocks.append(Transform3D(Basis.from_scale(rock_size), centre))
				_add_box(tool, centre, rock_size, random.randf_range(0.82, 1.0))
	tool.generate_normals()
	_mesh.mesh = tool.commit()
	_mesh.material_override = _material


static func _add_box(tool: SurfaceTool, centre: Vector3, box_size: Vector3, shade: float) -> void:
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
		for index in QUAD:
			tool.add_vertex(corners[index])
