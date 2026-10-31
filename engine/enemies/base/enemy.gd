class_name Enemy
extends Node3D
## Base for enemies: a small state machine that patrols, notices a player who comes close, attacks,
## and is stunned for a moment afterwards before patrolling again. Each kind of enemy fills in what
## those modes do (WalkerEnemy, FlyerEnemy, TurretEnemy, LeaperEnemy).
##
## Touching the player hurts them, unless they are curled up (jumping, rolling, spin dashing or
## homing in) or invincible: then the enemy is destroyed, bursting into an explosion and freeing an
## animal, and the player rebounds off it (Player.rebound_from()). It stays destroyed until the
## stage reloads.
##
## The scene needs a %Hitbox (an Area3D watching the player layer), a %HomingTarget where the homing
## attack should aim, and a %Model holding the visuals. If the model has an AnimationPlayer with
## animations named after the modes ("patrol", "notice", "attack", "stunned"), each one plays as its
## mode starts.

signal destroyed

enum Mode { PATROL, NOTICE, ATTACK, STUNNED, DESTROYED }

const GROUP := "enemies"
const MODE_ANIMATIONS: Array[StringName] = [&"patrol", &"notice", &"attack", &"stunned", &""]
const EXPLOSION_SCENE := "res://engine/enemies/base/explosion.tscn"

@export var notice_range: float = 8.0  ## Notices a player this close (m). 0 never notices anyone.
@export var notice_time: float = 0.5  ## Seconds between noticing a player and attacking.
@export var stun_time: float = 1.0  ## Seconds of pause after an attack.
@export var animal_scene: PackedScene = preload("res://engine/enemies/base/animal.tscn")  ## Freed when the enemy is destroyed. Empty frees nothing.

var mode := Mode.PATROL
var target: Player  ## The player being noticed or attacked.
var home := Vector3.ZERO  ## Where the enemy started, in global space.
var mode_time := 0.0  ## Seconds since the current mode began.

@onready var hitbox: Area3D = %Hitbox
@onready var homing_target: HomingTarget = %HomingTarget
@onready var model: Node3D = %Model

var _animations: AnimationPlayer


func _ready() -> void:
	add_to_group(GROUP)
	home = global_position
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_animations = found[0] as AnimationPlayer
	# Act on a touch before the player moves this tick, so a rolling player carries straight on.
	process_physics_priority = -1
	_set_mode(Mode.PATROL)


func _physics_process(delta: float) -> void:
	if mode == Mode.DESTROYED:
		return
	mode_time += delta
	if _touch_players():
		return
	match mode:
		Mode.PATROL:
			_patrol(delta)
			var noticed := _player_within(notice_range)
			if noticed:
				target = noticed
				_set_mode(Mode.NOTICE)
		Mode.NOTICE:
			_notice(delta)
			if mode_time >= notice_time:
				_set_mode(Mode.ATTACK)
		Mode.ATTACK:
			if _attack(delta):
				_set_mode(Mode.STUNNED)
		Mode.STUNNED:
			_stunned(delta)
			if mode_time >= stun_time:
				target = null
				_set_mode(Mode.PATROL)


## Bursts the enemy: an explosion, a freed animal, and the player who did it rebounds off it.
func destroy(by: Player) -> void:
	if mode == Mode.DESTROYED:
		return
	var center := homing_target.global_position
	_set_mode(Mode.DESTROYED)
	hitbox.set_deferred("monitoring", false)
	homing_target.enabled = false
	model.visible = false
	if by:
		by.rebound_from(center)
	var stage := get_parent()
	var explosion := (load(EXPLOSION_SCENE) as PackedScene).instantiate() as Node3D
	stage.add_child(explosion)
	explosion.global_position = center
	if animal_scene:
		var animal := animal_scene.instantiate() as Node3D
		stage.add_child(animal)
		animal.global_position = center
		if animal is Animal and by:
			(animal as Animal).flee_from(by.global_position)
	destroyed.emit()
	queue_free()


func is_destroyed() -> bool:
	return mode == Mode.DESTROYED


# --- What each kind of enemy fills in ------------------------------------------------------

## Every tick while patrolling.
func _patrol(_delta: float) -> void:
	pass


## Every tick between noticing `target` and attacking it.
func _notice(_delta: float) -> void:
	pass


## Every tick of the attack. Returns true once the attack is over.
func _attack(_delta: float) -> bool:
	return true


## Every tick of the pause after an attack.
func _stunned(_delta: float) -> void:
	pass


## Called as each mode begins.
func _enter_mode(_new_mode: Mode) -> void:
	pass


# --- Helpers ------------------------------------------------------------------------------

func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	mode_time = 0.0
	_enter_mode(new_mode)
	var animation := MODE_ANIMATIONS[new_mode]
	if _animations and animation != &"" and _animations.has_animation(animation):
		_animations.play(animation)


## The nearest living player within `distance` of the enemy, or null.
func _player_within(distance: float) -> Player:
	if distance <= 0.0:
		return null
	var best: Player = null
	var best_distance := distance
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player == null or player.is_dead():
			continue
		var gap := player.global_position.distance_to(global_position)
		if gap <= best_distance:
			best = player
			best_distance = gap
	return best


## Hurts or is destroyed by every player touching the hitbox. Returns whether it was destroyed.
func _touch_players() -> bool:
	if not hitbox.monitoring:
		return false
	for body in hitbox.get_overlapping_bodies():
		var player := body as Player
		if player == null or player.is_dead():
			continue
		if player.is_attacking() or player.is_invincible():
			destroy(player)
			return true
		player.hurt(global_position)
	return false


## Turns the enemy about its vertical axis to face along `direction` (flattened), at up to
## `rate` radians per second.
func _turn_toward(direction: Vector3, rate: float, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 1e-6:
		return
	var goal := atan2(-flat.x, -flat.z)
	rotation.y = rotate_toward(rotation.y, goal, rate * delta)
