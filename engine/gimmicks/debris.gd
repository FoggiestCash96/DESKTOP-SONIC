class_name Debris
extends Node3D
## Pieces of something broken flying apart: each tumbles away under gravity and shrinks to nothing,
## and the whole thing frees itself afterwards. Made by BreakableWall and CrumblingPlatform.

const LIFETIME := 1.4  ## Seconds before the pieces are gone.
const GRAVITY := 22.0  ## m/s²

var _pieces: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spins: Array[Vector3] = []
var _age := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Adds a piece drawn with `mesh` and `material` at `place` (in this node's space), flying off at
## `velocity` and spinning at `spin` (radians per second about each axis).
func add_piece(mesh: Mesh, material: Material, place: Transform3D, velocity: Vector3, spin: Vector3) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.transform = place
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	_pieces.append(piece)
	_velocities.append(velocity)
	_spins.append(spin)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var shrink := 1.0 - smoothstep(LIFETIME * 0.6, LIFETIME, _age)
	for i in _pieces.size():
		_velocities[i].y -= GRAVITY * delta
		var piece := _pieces[i]
		piece.position += _velocities[i] * delta
		piece.rotation += _spins[i] * delta
		piece.scale = Vector3.ONE * maxf(shrink, 0.01)
