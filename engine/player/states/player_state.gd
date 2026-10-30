class_name PlayerState
extends RefCounted
## One of the player's movement states. Every physics tick the player calls `tick()` on the
## current state before moving, then `after_move()` once the move's collisions are known.
## States switch through Player.change_state().

var player: Player


func _init(state_owner: Player) -> void:
	player = state_owner


## Name shown in the debug overlay.
func label() -> String:
	return "STATE"


func enter(_previous: PlayerState) -> void:
	pass


func exit() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func after_move(_delta: float) -> void:
	pass
