@tool
class_name ItemMonitor
extends StaticBody3D
## An item box. It's solid: a player standing up bumps into it or stands on it. Curled up (jumping,
## rolling, spin dashing or homing in) they break it open and get what's inside. Breaking it from
## above, or with a homing attack, bounces them back up.

enum Item { RINGS, SHIELD, SPEED_SHOES, INVINCIBILITY, MAGNET }

const ITEM_TEXT: Array[String] = ["RINGS", "SHIELD", "SHOES", "INVINCIBLE", "MAGNET"]
const ITEM_COLORS: Array[Color] = [
	Color(1.0, 0.8, 0.2), Color(0.35, 0.6, 1.0), Color(1.0, 0.35, 0.3), Color(1.0, 1.0, 0.85), Color(0.45, 1.0, 0.5),
]
const BOUNCE_HEIGHT := 0.6  ## A player whose feet are above this height on the box (m) bounces off it.

@export var item: Item = Item.RINGS:
	set(value):
		item = value
		_update_look()
@export var ring_amount: int = 10:  ## Rings in a RINGS monitor.
	set(value):
		ring_amount = value
		_update_look()

@onready var _shape: CollisionShape3D = %Shape
@onready var _detector: Area3D = %Detector
@onready var _box: Node3D = %Box
@onready var _screen: MeshInstance3D = %Screen
@onready var _label: Label3D = %Label
@onready var _homing_target: HomingTarget = %HomingTarget


func _ready() -> void:
	_update_look()
	# Break open before the player moves this tick, so a rolling player carries straight on.
	process_physics_priority = -1
	set_physics_process(not Engine.is_editor_hint())


func _physics_process(_delta: float) -> void:
	for body in _detector.get_overlapping_bodies():
		var player := body as Player
		if player and player.is_attacking():
			_break_open(player)
			return


func _break_open(player: Player) -> void:
	set_physics_process(false)
	_shape.disabled = true
	_box.visible = false
	_homing_target.enabled = false
	if player.is_homing() or player.global_position.y > global_position.y + BOUNCE_HEIGHT:
		player.bounce()
	match item:
		Item.RINGS:
			player.collect_rings(ring_amount)
		Item.SHIELD:
			player.give_shield()
		Item.SPEED_SHOES:
			player.give_speed_shoes()
		Item.INVINCIBILITY:
			player.give_invincibility()
		Item.MAGNET:
			player.give_magnet()
	var rise := create_tween()
	rise.tween_property(_label, "position:y", _label.position.y + 1.0, 0.5)
	rise.tween_property(_label, "modulate:a", 0.0, 0.4)


func _update_look() -> void:
	if not is_node_ready():
		return
	var color := ITEM_COLORS[item]
	_label.text = "%d RINGS" % ring_amount if item == Item.RINGS else ITEM_TEXT[item]
	_label.modulate = color
	var current := _screen.material_override as StandardMaterial3D
	if current and current.albedo_color == color:
		return  # Unchanged, so opening a scene in the editor doesn't mark it as modified.
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.6
	_screen.material_override = material
