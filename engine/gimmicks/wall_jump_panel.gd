@tool
class_name WallJumpPanel
extends Area3D
## A wall-jump panel: a patch of wall that a player who jumps into it clings to (WallClingState)
## and kicks off with jump (Player.wall_jump()). Put it flat on a wall with its +Z axis pointing out
## of the wall, toward the players; two panels facing each other across a shaft make a climb. Its
## origin is the middle of the panel, on the wall. It builds its own plate and catch area from
## `size`, in the editor as well as in the game. Ordinary walls can't be clung to.

const REACH := 1.0  ## The catch area reaches this far out from the wall (m).
const THICKNESS := 0.06  ## The plate stands this far out from the wall (m).
const MIN_APPROACH := 0.5  ## A player has to be moving toward the panel at least this fast to be caught (m/s).

@export var size := Vector2(3.0, 4.0):  ## Width (X) and height (Y) of the panel (m).
	set(value):
		size = value
		if is_inside_tree():
			_build()
@export var material: Material:  ## The panel's look. Empty takes the art bank's "wall_jump_panel".
	set(value):
		material = value
		if is_inside_tree():
			_build()

var _plate: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 1 << 3  # gimmicks
	collision_mask = 1 << 1  # player
	monitorable = false
	_build()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	process_physics_priority = -1  # Catches the player before they move this tick.


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player and player.velocity.dot(-normal()) >= MIN_APPROACH and holds(player.body_center()):
			player.cling_to(self)


## The way out of the wall, as a unit vector.
func normal() -> Vector3:
	return global_basis.z.normalized()


## Whether `point` is in front of the panel, within its width and height.
func holds(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and local.z >= -0.2 and local.z <= REACH + 0.5


## The point on the panel's face nearest `point`.
func surface_point(point: Vector3) -> Vector3:
	var local := global_transform.affine_inverse() * point
	return global_transform * Vector3(local.x, local.y, THICKNESS)


func _build() -> void:
	if _plate == null:
		_plate = MeshInstance3D.new()
		_plate.name = "Plate"
		add_child(_plate)
		_shape = CollisionShape3D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, THICKNESS)
	_plate.mesh = mesh
	_plate.position = Vector3(0.0, 0.0, THICKNESS * 0.5)
	_plate.material_override = material if material else ArtBank.material(&"wall_jump_panel", _fallback_material())
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, REACH)
	_shape.shape = box
	_shape.position = Vector3(0.0, 0.0, REACH * 0.5)


static func _fallback_material() -> Material:
	var look := StandardMaterial3D.new()
	look.albedo_color = Color(0.2, 0.45, 0.95)
	look.emission_enabled = true
	look.emission = Color(0.2, 0.45, 0.95)
	look.emission_energy_multiplier = 0.4
	return look
