@tool
class_name Spring
extends Area3D
## A spring. Touching it launches the player along the spring's +Y axis (turn the node to aim it).
## An upward spring keeps the player's running speed by default, as classic springs do, and a
## spring lying on its side sends a grounded player along the ground instead.

const YELLOW := Color(1.0, 0.85, 0.15)
const RED := Color(0.95, 0.2, 0.15)
const RED_FROM := 24.0  ## Springs at least this fast (m/s) are painted red, like the classic strong springs.

@export var speed: float = 10.0 * PlayerPhysics.SPEED:  ## Launch speed (m/s). The classic yellow spring is 18.75 (10 px/frame), the red one 30 (16 px/frame).
	set(value):
		speed = value
		_update_look()
@export var keep_momentum: bool = true  ## Keep the player's speed across the launch direction. Turn it off to launch exactly along the spring, as for a diagonal spring aimed at a ledge.
@export var control_lock: float = 0.0  ## Seconds the stick is ignored after a launch. Classic sideways springs use 0.27 (16 frames).

var _launched: Array[Player] = []  # Players still touching since their launch, so each touch launches once.

@onready var _pad: MeshInstance3D = %Pad


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	# Launch before the player moves this tick.
	process_physics_priority = -1
	body_entered.connect(func(_body: Node3D) -> void: set_physics_process(true))
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var touching: Array[Player] = []
	for body in get_overlapping_bodies():
		var player := body as Player
		if player == null or player.is_dead():
			continue
		touching.append(player)
		if player not in _launched:
			_launch(player)
	_launched = touching
	if touching.is_empty():
		set_physics_process(false)


func _launch(player: Player) -> void:
	var direction := global_basis.y.normalized()
	if player.is_grounded() and GimmickMath.runs_along(direction, player.ground_normal):
		player.push_along_ground(direction, speed, false, control_lock)
	else:
		player.launch(GimmickMath.spring_velocity(player.velocity, direction, speed, keep_momentum), control_lock)
	var squash := create_tween()
	squash.tween_property(_pad, "scale:y", 0.4, 0.05)
	squash.tween_property(_pad, "scale:y", 1.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update_look() -> void:
	if not is_node_ready():
		return
	var color := RED if speed >= RED_FROM else YELLOW
	var current := _pad.material_override as StandardMaterial3D
	if current and current.albedo_color == color:
		return  # Unchanged, so opening a scene in the editor doesn't mark it as modified.
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	_pad.material_override = material
