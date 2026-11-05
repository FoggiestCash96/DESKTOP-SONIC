@tool
class_name WaterVolume
extends Node3D
## A body of water. Its surface is this node's XZ plane (at low tide), `size.x` wide along X and
## `size.z` long along Z, and the water reaches `size.y` below it. Below the surface the player
## swims (Player: slower movement, lighter gravity and an air timer), and the camera tints the view.
##
## A current carries anything in the water along -Z (turn the node to aim it; tilt it to run a
## stream down a slope), and a tide raises the surface by `tide_height` on a timer, flooding what
## lies below. In the editor a faint box shows the water at high tide.

const GROUP := "water_volumes"

@export var size := Vector3(20.0, 6.0, 20.0):  ## Width (X), depth below the surface (Y) and length (Z) of the water (m).
	set(value):
		size = value
		_update_shape()
@export var current_speed: float = 0.0:  ## Speed the water carries the player at, along -Z (m/s). 0 is still water.
	set(value):
		current_speed = value
		_update_shape()
@export var current_push: float = 15.0  ## How hard the current pushes (m/s²).
@export var tide_height: float = 0.0:  ## How far the surface rises at high tide (m). 0 is no tide.
	set(value):
		tide_height = value
		_update_shape()
@export_range(0.0, 120.0) var tide_low_time: float = 10.0  ## Seconds the tide stays low...
@export_range(0.1, 120.0) var tide_rise_time: float = 6.0  ## ...rises over...
@export_range(0.0, 120.0) var tide_high_time: float = 8.0  ## ...stays high...
@export_range(0.1, 120.0) var tide_fall_time: float = 6.0  ## ...and falls over.
@export var start_time: float = 0.0  ## Seconds into the tide's cycle when the stage starts, to stagger neighbouring tides.
@export var surface_material: Material:  ## The surface's look. Empty takes the art bank's "water", or "water_flowing" for a current.
	set(value):
		surface_material = value
		_update_shape()
@export var show_surface: bool = true:  ## Off where the stage's art draws the water itself.
	set(value):
		show_surface = value
		_update_shape()

var _time := 0.0
var _level := 0.0  # How far the surface is above its low-tide height (m).
var _surface: MeshInstance3D
var _preview: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	_time = start_time
	_update_shape()
	# Move the water and push before the player moves this tick.
	process_physics_priority = -1
	set_physics_process(not Engine.is_editor_hint())


func _physics_process(delta: float) -> void:
	_time += delta
	if tide_height > 0.0:
		_level = tide_height * tide_level()
		_surface.position.y = _level
	if current_speed <= 0.0:
		return
	var along := -global_basis.z
	var flat := Vector3(along.x, 0.0, along.z).normalized()
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player and contains(player.global_position + Vector3.UP * 0.2):
			player.push(flat, current_speed, current_push * delta)


## How high the tide is now, from 0 (low) to 1 (high).
func tide_level() -> float:
	if tide_height <= 0.0:
		return 0.0
	return GimmickMath.tide_level(_time, tide_low_time, tide_rise_time, tide_high_time, tide_fall_time)


## Whether `point` is in the water: inside the box and below the surface as it is now.
func contains(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.z * 0.5 and local.y <= _level and local.y >= -size.y


## The height of the surface right above or below `point`.
func surface_height(point: Vector3) -> float:
	var local := to_local(point)
	return to_global(Vector3(local.x, _level, local.z)).y


## The water `point` is in, if any.
static func find(tree: SceneTree, point: Vector3) -> WaterVolume:
	for node in tree.get_nodes_in_group(GROUP):
		var water := node as WaterVolume
		if water and water.contains(point):
			return water
	return null


func _update_shape() -> void:
	if not is_node_ready():
		return
	if _surface == null:
		_surface = MeshInstance3D.new()
		_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_surface)
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	plane.subdivide_width = clampi(int(size.x / 8.0), 0, 16)
	plane.subdivide_depth = clampi(int(size.z / 8.0), 0, 16)
	_surface.mesh = plane
	_surface.position = Vector3(0.0, _level, 0.0)
	_surface.visible = show_surface
	var look := surface_material
	if look == null:
		look = ArtBank.material(&"water_flowing" if current_speed > 0.0 else &"water")
	_surface.material_override = look
	# Ripples drift with the current (toon_water's `flow`, set on each surface).
	var along := -global_basis.z if is_inside_tree() else -basis.z
	_surface.set_instance_shader_parameter(&"flow", Vector2(along.x, along.z).normalized() * current_speed if current_speed > 0.0 else Vector2.ZERO)
	_update_preview()


func _update_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if _preview == null:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.2, 0.5, 1.0, 0.12)
		_preview = MeshInstance3D.new()
		_preview.material_override = material
		_preview.mesh = BoxMesh.new()
		add_child(_preview)
	var height := size.y + tide_height
	(_preview.mesh as BoxMesh).size = Vector3(size.x, height, size.z)
	_preview.position = Vector3(0.0, tide_height - height * 0.5, 0.0)
