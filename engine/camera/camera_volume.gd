@tool
class_name CameraVolume
extends Node3D
## A box that takes over the player camera while the player is inside it, for set pieces and
## 2.5D sections. The camera faces this node's -Z axis (turn the node to aim it), tilted by
## pitch_degrees, from `distance` away, and blends in and out over blend_time. A side-view volume
## is for a 2.5D path that runs along the box's X axis: the camera only aims ahead along that axis,
## and with lock_depth the player is held to the path too, and eased onto it as they come in (from
## `lead_in` before either end). A volume with a `focus` turns the camera to keep that node in view
## beyond the player instead, as for a boss. Where volumes overlap, the highest priority wins. The
## box shows in the editor only.

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
@export var lock_depth: bool = false  ## Hold the player to the box's middle plane (its X axis and up) while inside, so a side view plays in 2.5D: no stepping off the path into depth.
@export var lead_in: float = 16.0  ## With lock_depth: players heading into the box are eased onto its path from this far (m) before either end, out of a funnel that widens as it goes, so they reach the box on the path. 0 turns it off.
@export var avoid_walls: bool = true  ## Pull the camera in front of walls. Turn off where the view looks through geometry on purpose, such as the side of a loop.
@export var priority: int = 0
@export var focus: Node3D  ## Keeps this in view: the camera looks past the player at it, ignoring the volume's own facing.

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


## Direction of a 2.5D path through the volume: the box's X axis.
func path_axis() -> Vector3:
	return global_basis.x.normalized()


## Direction across a 2.5D path, into the screen and out: the box's Z axis.
func depth_axis() -> Vector3:
	return global_basis.z.normalized()


## How far `point` is from a 2.5D path's plane, along depth_axis (m).
func path_offset(point: Vector3) -> float:
	return (point - global_position).dot(depth_axis())


## The direction along the path toward the middle of the box from `point`: the way into the
## section from wherever the player is.
func inward(point: Vector3) -> Vector3:
	return path_axis() * (-1.0 if (point - global_position).dot(path_axis()) > 0.0 else 1.0)


## When `point` is in one of the lead-ins before the box's ends (see `lead_in`), the direction along
## the path into the box from there. ZERO when it isn't. The funnel widens `flare` m across for
## every metre further out.
func lead_in_direction(point: Vector3, flare: float) -> Vector3:
	if not lock_depth or lead_in <= 0.0:
		return Vector3.ZERO
	var local := global_transform.affine_inverse() * point
	if CameraMath.lead_in_distance(local, size * 0.5, lead_in, flare) <= 0.0:
		return Vector3.ZERO
	return inward(point)


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
