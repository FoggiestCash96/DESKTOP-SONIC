class_name Explosion
extends Node3D
## A puff of fire where an enemy was destroyed: a ball that swells and fades, then frees itself.

@export var size: float = 1.6  ## Diameter it swells to (m).
@export var duration: float = 0.4  ## Seconds it lasts.

@onready var _ball: MeshInstance3D = %Ball


func _ready() -> void:
	# Each explosion fades on its own, so it needs its own copy of the material.
	var material := (_ball.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	_ball.material_override = material
	_ball.scale = Vector3.ONE * 0.2
	var tween := create_tween().set_parallel()
	tween.tween_property(_ball, "scale", Vector3.ONE * size, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(material, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
