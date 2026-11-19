class_name HiddenCollectible
extends Area3D
## One of the collectibles hidden in each act (five red rings, in this game). GameState counts them
## for the HUD. A found one stays found for the rest of the visit: after a death it shows greyed out.
## One found on an earlier clear of the act (saved on the save slot) shows greyed out too, and can be
## collected again for this visit's count. Each fills its own slot in the HUD, wherever it is found
## in the act and in whatever order.

@export var found_material: Material  ## Look of one already found, shown after the stage restarts.
@export var slot: int = 0  ## Which of the HUD's slots this one fills (1 for the first). 0 takes the number its name ends with, so RedRing3 fills the third.

@onready var _mesh: MeshInstance3D = %Mesh


func _ready() -> void:
	GameState.hidden_total += 1
	var id := GameState.id_of(self)
	GameState.hidden_slots[id] = slot if slot > 0 else GameState.number_at_end(String(name))
	if GameState.is_found(id) or SaveGame.red_rings(GameState.stage).has(id):
		_mesh.material_override = found_material
	if not GameState.is_found(id):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and GameState.find(GameState.id_of(self), true):
		Sfx.play(&"red_ring")
		queue_free()
