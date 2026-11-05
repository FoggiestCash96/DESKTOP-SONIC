@tool
class_name CrumblingPlatform
extends AnimatableBody3D
## A ledge that gives way. Once a player stands on it, it shakes for `delay` seconds, then crumbles
## and falls, and comes back `respawn_time` seconds later (once nobody is in its way). Its origin is
## the middle of its top, so place it where the top should be.

enum Phase { WAITING, SHAKING, FALLING, GONE }

const SHAKE := 0.06  ## How far it jitters while shaking (m).
const FALL_GRAVITY := 18.0  ## m/s²
const SOLID_FALL := 1.5  ## It stops being solid once it has fallen this far (m)...
const GONE_TIME := 1.2  ## ...and is gone this many seconds after it started to fall.

@export var size := Vector3(4.0, 1.0, 4.0):  ## Width (X), thickness (Y) and length (Z) of the ledge (m).
	set(value):
		size = value
		_update_shape()
@export var delay: float = 0.5  ## Seconds it shakes before it falls.
@export var respawn_time: float = 6.0  ## Seconds after falling before it comes back.

var _phase := Phase.WAITING
var _timer := 0.0
var _fall_speed := 0.0
var _start: Transform3D
var _shape: CollisionShape3D
var _look: Node3D


func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	sync_to_physics = true
	_start = transform
	process_physics_priority = -2


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match _phase:
		Phase.WAITING:
			if _stood_on():
				_phase = Phase.SHAKING
				_timer = delay
				Sfx.play_at(&"crumble", global_position)
		Phase.SHAKING:
			_timer -= delta
			_look.position = Vector3(randf_range(-SHAKE, SHAKE), 0.0, randf_range(-SHAKE, SHAKE))
			if _timer <= 0.0:
				_phase = Phase.FALLING
				_timer = 0.0
				_fall_speed = 0.0
				_look.position = Vector3.ZERO
				_crumble()
		Phase.FALLING:
			_timer += delta
			_fall_speed += FALL_GRAVITY * delta
			position.y -= _fall_speed * delta
			if _start.origin.y - position.y > SOLID_FALL:
				_shape.disabled = true
			if _timer >= GONE_TIME:
				_phase = Phase.GONE
				_timer = respawn_time
				visible = false
		Phase.GONE:
			_timer -= delta
			if _timer <= 0.0 and not _player_in_the_way():
				transform = _start
				_shape.disabled = false
				visible = true
				_phase = Phase.WAITING


## Whether a player is standing on the top.
func _stood_on() -> bool:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player and player.is_grounded() and _over_top(player.global_position, 0.6):
			return true
	return false


func _player_in_the_way() -> bool:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player and _over_top(player.global_position, 2.0):
			return true
	return false


## Whether `point` is over the footprint, between just below the top and `above` metres over it.
func _over_top(point: Vector3, above: float) -> bool:
	var local := (get_parent_node_3d().global_transform * _start).affine_inverse() * point if get_parent_node_3d() else _start.affine_inverse() * point
	return absf(local.x) <= size.x * 0.5 + 0.2 and absf(local.z) <= size.z * 0.5 + 0.2 and local.y > -size.y - 0.3 and local.y < above


## A few chunks break off as it starts to fall.
func _crumble() -> void:
	var debris := Debris.new()
	get_parent().add_child(debris)
	debris.global_transform = global_transform
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * minf(0.5, size.y * 0.6)
	var material := PlatformLook.material(&"crumbling_rock")
	for i in 8:
		var at := Vector3(randf_range(-0.5, 0.5) * size.x, -size.y * randf_range(0.3, 0.9), randf_range(-0.5, 0.5) * size.z)
		debris.add_piece(chunk, material, Transform3D(Basis.IDENTITY, at), Vector3(randf_range(-2.0, 2.0), randf_range(0.0, 2.0), randf_range(-2.0, 2.0)), Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), 0.0))


func _update_shape() -> void:
	if not is_node_ready():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		add_child(_shape)
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position = Vector3(0.0, -size.y * 0.5, 0.0)
	if _look:
		_look.queue_free()
	_look = PlatformLook.build(false, size, &"crumbling_rock")
	add_child(_look)
