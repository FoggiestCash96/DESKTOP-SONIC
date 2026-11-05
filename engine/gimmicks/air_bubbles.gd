class_name AirBubbles
extends Node3D
## A vent in the floor under water that breathes out bubbles: a trickle of small ones, and every
## `interval` seconds a big one that rises to the surface. Touching a big bubble gives the player a
## breath of air (Player.breathe()), the way to stay under water for longer.

const SMALL_BUBBLES := 6
const SMALL_SPEED := 1.6  ## How fast the small bubbles rise (m/s).
const POP_TIME := 0.15  ## Seconds a big bubble takes to burst.

@export var interval: float = 4.0  ## Seconds between big bubbles.
@export var start_time: float = 0.0  ## Seconds into the first interval when the stage starts.
@export var rise_speed: float = 1.2  ## How fast a big bubble rises (m/s).
@export var big_radius: float = 0.45  ## Size of a big bubble (m).
@export var reach: float = 0.9  ## A big bubble this close to the middle of a player under water gives them air (m).

var _timer := 0.0
var _bubbles: Array[MeshInstance3D] = []  # Big bubbles on their way up.
var _small: Array[MeshInstance3D] = []
var _height := 4.0  # How far the small bubbles rise before they start again (m).
var _material: Material
var _time := 0.0


func _ready() -> void:
	ModelSkin.apply(self, ArtBank.model(&"air_bubbles"))
	_material = ArtBank.material(&"bubble", _default_material())
	_timer = start_time
	var water := WaterVolume.find(get_tree(), global_position + Vector3.UP * 0.3)
	if water:
		_height = maxf(water.surface_height(global_position) - global_position.y, 0.5)
	for i in SMALL_BUBBLES:
		var bubble := _bubble(0.06 + 0.04 * float(i % 3))
		_small.append(bubble)
	# Give air before the player moves this tick.
	process_physics_priority = -1


func _process(delta: float) -> void:
	_time += delta
	for i in _small.size():
		var rise := fmod(_time * SMALL_SPEED + _height * float(i) / SMALL_BUBBLES, _height)
		var wobble := 0.12 * sin(_time * 5.0 + float(i) * 1.7)
		_small[i].position = Vector3(wobble, 0.2 + rise, 0.1 * cos(_time * 4.0 + float(i)))


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= interval:
		_timer -= interval
		var bubble := _bubble(big_radius)
		bubble.position = Vector3(0.0, 0.3, 0.0)
		_bubbles.append(bubble)
	for bubble: MeshInstance3D in _bubbles.duplicate():
		bubble.position.y += rise_speed * delta
		bubble.position.x = 0.15 * sin(bubble.position.y * 2.0)
		var at := bubble.global_position
		if WaterVolume.find(get_tree(), at) == null:
			_pop(bubble)
			continue
		for node in get_tree().get_nodes_in_group(Player.GROUP):
			var player := node as Player
			if player and player.is_underwater() and player.ball_center().distance_to(at) < reach + big_radius * 0.5:
				player.breathe()
				_pop(bubble)
				break


func _bubble(radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var bubble := MeshInstance3D.new()
	bubble.mesh = mesh
	bubble.material_override = _material
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bubble)
	return bubble


func _pop(bubble: MeshInstance3D) -> void:
	_bubbles.erase(bubble)
	var burst := create_tween()
	burst.tween_property(bubble, "scale", Vector3.ONE * 1.6, POP_TIME)
	burst.parallel().tween_property(bubble, "transparency", 1.0, POP_TIME)
	burst.tween_callback(bubble.queue_free)


static func _default_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.85, 0.95, 1.0, 0.45)
	material.rim_enabled = true
	material.rim = 1.0
	return material
