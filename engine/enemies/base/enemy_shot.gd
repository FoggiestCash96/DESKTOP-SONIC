class_name EnemyShot
extends Area3D
## A shot fired by an enemy. It flies straight, hurts a player it touches even if they are curled
## up, as classic shots do (a shield or invincibility still protects them), and bursts on level
## geometry or after `lifetime`.

@export var speed: float = 8.0  ## (m/s)
@export var lifetime: float = 4.0  ## Seconds before it bursts on its own.

var direction := Vector3.FORWARD  ## Which way it flies, as a unit vector.
var _age := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Fires the shot from where it is toward `point`.
func aim_at(point: Vector3) -> void:
	var offset := point - global_position
	if offset.length_squared() > 1e-6:
		direction = offset.normalized()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player:
		if player.is_dead():
			return
		player.hurt(global_position)
	queue_free()
