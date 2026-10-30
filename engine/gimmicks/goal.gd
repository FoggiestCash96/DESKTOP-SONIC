class_name Goal
extends Area3D
## The end of an act. Running through it stops the clock and takes the controls away while the
## player coasts to a stop; the results show, and then the stage moves on. The sign spins.

@onready var _sign: Node3D = %Sign


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or player.is_dead() or GameState.cleared:
		return
	player.set_input_enabled(false)
	GameState.clear_stage(player.rings)
	var spin := create_tween()
	spin.tween_property(_sign, "rotation:y", _sign.rotation.y + TAU * 4.0, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
