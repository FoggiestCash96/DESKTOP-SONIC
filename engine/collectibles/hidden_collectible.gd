class_name HiddenCollectible
extends Area3D
## One of the collectibles hidden in each act (five red rings, in this game). GameState counts them
## for the HUD. A found one stays found for the rest of the visit: after a death it shows greyed out.
## One found on an earlier clear of the act (saved on the save slot) shows greyed out too, and can be
## collected again for this visit's count.

@export var found_material: Material  ## Look of one already found, shown after the stage restarts.

@onready var _mesh: MeshInstance3D = %Mesh


func _ready() -> void:
	GameState.hidden_total += 1
	var id := GameState.id_of(self)
	if GameState.is_found(id) or SaveGame.red_rings(GameState.stage).has(id):
		_mesh.material_override = found_material
	if not GameState.is_found(id):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and GameState.find(GameState.id_of(self), true):
		queue_free()
