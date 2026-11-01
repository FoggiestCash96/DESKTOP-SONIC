extends Node3D
## The title screen's backdrop: Sonic on a rock in the shallows of Emerald Shore, the camera
## drifting slowly from side to side.

@export var pose: StringName = &"victory"
@export var sway_degrees: float = 7.0  ## How far the camera drifts each way.
@export var sway_time: float = 26.0  ## Seconds for the camera to drift there and back.

var _time: float = 0.0

@onready var _pivot: Node3D = %CameraPivot
@onready var _sonic: CharacterModel = %Sonic


func _ready() -> void:
	_sonic.animate(pose, 0.0)


func _process(delta: float) -> void:
	_time += delta
	_pivot.rotation.y = deg_to_rad(sway_degrees) * sin(_time * TAU / sway_time)
