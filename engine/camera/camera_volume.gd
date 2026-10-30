@tool
class_name CameraVolume
extends Node3D
## A box that takes over the player camera while the player is inside it, for set pieces and
## 2.5D sections. The camera faces this node's -Z axis (turn the node to aim it), tilted by
## pitch_degrees, from `distance` away, and blends in and out over blend_time. A side-view volume
## is for a 2.5D path that runs along the box's X axis: the camera only aims ahead along that axis.
## Where volumes overlap, the highest priority wins. The box shows in the editor only.

const GROUP := "camera_volumes"

@export var size := Vector3(10.0, 10.0, 10.0):
	set(value):
		size = value
		_update_preview()
@export var pitch_degrees: float = -10.0  ## Negative looks down.
@export var distance: float = 10.0  ## Camera distance from the player (m).
@export var fov: float = 0.0  ## Field of view (degrees). 0 keeps the camera's speed-based field of view.
@export var blend_time: float = 0.6  ## Seconds to blend into this view, and back out of it.
@export var side_view: bool = false  ## A 2.5D section along the box's X axis.
@export var avoid_walls: bool = true  ## Pull the camera in front of walls. Turn off where the view looks through geometry on purpose, such as the side of a loop.
@export var priority: int = 0

var _preview: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	_update_preview()


## Whether `point` is inside the volume.
func contains(point: Vector3) -> bool:
	return CameraMath.box_contains(global_transform, size, point)


## Yaw of the view this volume asks for.
func view_yaw() -> float:
	return CameraMath.yaw_facing(-global_basis.z)


func _update_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	if _preview == null:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.3, 0.8, 1.0, 0.12)
		_preview = MeshInstance3D.new()
		_preview.material_override = material
		_preview.mesh = BoxMesh.new()
		add_child(_preview)
	(_preview.mesh as BoxMesh).size = size
