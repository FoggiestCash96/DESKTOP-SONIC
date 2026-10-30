class_name Checkpoint
extends Area3D
## A checkpoint post. Passing it saves the spot: after a death the stage restarts here, facing the
## post's -Z axis, with the stage clock as it was when the post was touched. The lamp turns from
## blue to red once touched. Passing anywhere through the gate around the post counts.

const SPAWN_AHEAD := 1.0  ## How far in front of the post (along -Z) the player restarts (m).
const GATE_HEIGHT := 3.0
const GATE_DEPTH := 0.8
const UNLIT := Color(0.25, 0.45, 1.0)
const LIT := Color(1.0, 0.25, 0.2)

@export var gate_width: float = 4.0  ## Width of the gate around the post (m). Make it as wide as the course, so no route misses it.

@onready var _gate: CollisionShape3D = %Gate
@onready var _head: Node3D = %Head
@onready var _lamp: MeshInstance3D = %Lamp


func _ready() -> void:
	var gate := BoxShape3D.new()
	gate.size = Vector3(gate_width, GATE_HEIGHT, GATE_DEPTH)
	_gate.shape = gate
	_gate.position = Vector3(0.0, GATE_HEIGHT * 0.5, 0.0)
	_light(GameState.checkpoint_touched(GameState.id_of(self)))
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var spawn := global_transform.orthonormalized().translated_local(Vector3.FORWARD * SPAWN_AHEAD)
	if body is Player and GameState.touch_checkpoint(GameState.id_of(self), spawn):
		_light(true)
		var spin := create_tween()
		spin.tween_property(_head, "rotation:y", _head.rotation.y + TAU * 3.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _light(on: bool) -> void:
	var color := LIT if on else UNLIT
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	_lamp.material_override = material
