class_name ExtraLife
extends Area3D
## A hidden extra life. Each one gives a life once per visit to the stage: one found before a death
## stays found when the stage restarts.


func _ready() -> void:
	if GameState.is_found(GameState.id_of(self)):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and GameState.find(GameState.id_of(self), false):
		GameState.add_life()
		queue_free()
