class_name HomingTarget
extends Marker3D
## A point the player's homing attack can lock on to and aims at. Enemies, item monitors and a
## boss's weak point carry one. Switch `enabled` off while the thing can't be hit: hidden,
## destroyed, broken open or armoured.

const GROUP := "homing_targets"

@export var enabled: bool = true


func _ready() -> void:
	add_to_group(GROUP)
