@tool
class_name WallRunStrip
extends Area3D
## A wall-run strip: a band along a wall that a player who jumps at it, going at least
## wall_run_min_speed along it, runs along (WallRunState) with their feet on the wall. Put it flat on
## a wall with its +Z axis pointing out of the wall; the player runs along its X axis, from its
## origin (the start of the running line) for `length` metres, on the line through the middle of
## its height. It builds its own band and catch area, in the editor as well as in the game.
## Ordinary walls can't be run on.

const REACH := 1.5  ## The catch area reaches this far out from the wall (m).
const THICKNESS := 0.04  ## The band stands this far out from the wall (m).

@export var length := 20.0:  ## Length of the running line (m).
	set(value):
		length = maxf(value, 1.0)
		if is_inside_tree():
			_build()
@export var height := 2.0:  ## Height of the band, centred on the running line (m).
	set(value):
		height = maxf(value, 0.5)
		if is_inside_tree():
			_build()
@export var material: Material:  ## The band's look. Empty takes the art bank's "wall_run_strip".
	set(value):
		material = value
		if is_inside_tree():
			_build()

var _band: MeshInstance3D
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
		if player == null:
			continue
		var speed := player.velocity.dot(along())
		if absf(speed) >= player.physics.wall_run_min_speed:
			player.start_wall_run(self, closest_offset(player.global_position), signf(speed))


## The way along the strip, from its start to its end, as a unit vector.
func along() -> Vector3:
	return global_basis.x.normalized()


## The way out of the wall, as a unit vector.
func normal() -> Vector3:
	return global_basis.z.normalized()


## Where a player `offset` metres along the strip puts their feet, `gap` metres off the wall.
func foot_point(offset: float, gap: float) -> Vector3:
	return global_transform * Vector3(offset, 0.0, gap)


## How far along the strip the point nearest `point` is (m).
func closest_offset(point: Vector3) -> float:
	return clampf((global_transform.affine_inverse() * point).x, 0.0, length)


func _build() -> void:
	if _band == null:
		_band = MeshInstance3D.new()
		_band.name = "Band"
		add_child(_band)
		_shape = CollisionShape3D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, height, THICKNESS)
	_band.mesh = mesh
	_band.position = Vector3(length * 0.5, 0.0, THICKNESS * 0.5)
	_band.material_override = material if material else ArtBank.material(&"wall_run_strip", _fallback_material())
	var box := BoxShape3D.new()
	box.size = Vector3(length, height + 1.0, REACH)
	_shape.shape = box
	_shape.position = Vector3(length * 0.5, 0.0, REACH * 0.5)


static func _fallback_material() -> Material:
	var look := StandardMaterial3D.new()
	look.albedo_color = Color(0.95, 0.75, 0.15)
	look.emission_enabled = true
	look.emission = Color(0.95, 0.75, 0.15)
	look.emission_energy_multiplier = 0.4
	return look
