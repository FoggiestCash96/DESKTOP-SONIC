class_name Boss
extends Node3D
## Base for bosses. A boss takes `hits` hits. It moves on a phase each time its hits left reach one of
## `phase_changes` (EnemyMath.boss_phase()), flashes for `hit_flash_time` after each hit, during
## which it can't be hit again, and throws the player back off it (Player.bounce_back()). When the
## last hit lands it is defeated, and with `clears_stage` the stage is cleared `defeat_time` later.
##
## The fight starts when a BossArena calls begin(). A boss with an intro overrides begin() and calls
## start_fight() when the intro is over; each kind of boss fills in _fight() and the hooks below.
##
## Parts of the scene:
## - %WeakPoint, an Area3D: a curled-up or invincible player touching it lands a hit while the boss
##   is `vulnerable` and not flashing. Its %HomingTarget is enabled only then.
## - %Model: the visuals, which flash after a hit.
## - `body_areas`: touching these hurts a player standing up; a curled-up player bounces off.
## - `danger_areas`: touching these hurts any player (unless they're invincible), while the area is
##   monitoring. Switch an attack's area on only while it is dangerous.

signal fight_started
signal hit_taken(hits_left: int)
signal phase_changed(phase: int)
signal defeated

const GROUP := "bosses"
const FLASH_PERIOD := 0.08  ## Seconds per flash after a hit.
const CONTACT_GRACE := 0.4  ## Seconds after a hit or a bounce during which touching the body does nothing.

@export var display_name: String = ""  ## Shown with its hits left on the HUD.
@export var hits: int = 8
@export var phase_changes: Array[int] = [4, 2]  ## Hits left at which the next phase starts.
@export var hit_flash_time: float = 1.0  ## Seconds it can't be hit after a hit.
@export var rebound_speed: float = 7.0  ## How fast a hit throws the player back, away from the weak point (m/s)...
@export var rebound_rise: float = 10.0  ## ...and up (m/s).
@export var bounce_off_speed: float = 6.0  ## How fast a curled-up player bounces off its body (m/s)...
@export var bounce_off_rise: float = 6.0  ## ...and up (m/s).
@export var clears_stage: bool = true  ## Defeating it clears the stage, as reaching a goal does.
@export var defeat_time: float = 3.0  ## Seconds from the last hit to the stage clearing.
@export var body_areas: Array[Area3D] = []
@export var danger_areas: Array[Area3D] = []

var hits_left := 0
var phase := 0
var fighting := false  ## The fight has started and the boss isn't defeated yet.
var vulnerable := false  ## Open to a hit on the weak point. Each kind of boss decides when.
var target: Player  ## The player being fought.

var _flash := 0.0
var _grace := 0.0

@onready var weak_point: Area3D = %WeakPoint
@onready var homing_target: HomingTarget = %HomingTarget
@onready var model: Node3D = %Model


func _ready() -> void:
	add_to_group(GROUP)
	hits_left = hits
	homing_target.enabled = false
	# Act on touches before the player moves this tick.
	process_physics_priority = -1


func _physics_process(delta: float) -> void:
	if not fighting:
		return
	_flash = maxf(_flash - delta, 0.0)
	_grace = maxf(_grace - delta, 0.0)
	model.visible = _flash <= 0.0 or fmod(_flash, FLASH_PERIOD * 2.0) < FLASH_PERIOD
	homing_target.enabled = vulnerable and _flash <= 0.0
	_touch_players()
	if fighting:
		_fight(delta)


## Called by the BossArena as the player arrives. Starts the fight at once; a boss with an intro
## overrides this and calls start_fight() when the intro is over.
func begin(player: Player) -> void:
	target = player
	start_fight()


func start_fight() -> void:
	fighting = true
	fight_started.emit()


func is_flashing() -> bool:
	return _flash > 0.0


# --- What each kind of boss fills in -------------------------------------------------------

## Every tick of the fight.
func _fight(_delta: float) -> void:
	pass


## After a hit that doesn't change the phase or end the fight.
func _on_hit() -> void:
	pass


## As each new phase starts.
func _on_phase_changed(_new_phase: int) -> void:
	pass


## On the last hit. The stage clears defeat_time later.
func _on_defeated() -> void:
	pass


# --- Contacts -----------------------------------------------------------------------------

func _touch_players() -> void:
	for body in weak_point.get_overlapping_bodies():
		var player := body as Player
		if player and not player.is_dead() and vulnerable and _flash <= 0.0 and (player.is_attacking() or player.is_invincible()):
			_take_hit(player)
			return
	for area in danger_areas:
		if not area.monitoring:
			continue
		for body in area.get_overlapping_bodies():
			var player := body as Player
			if player and not player.is_dead():
				player.hurt(area.global_position)
	if _grace > 0.0:
		return
	for area in body_areas:
		if not area.monitoring:
			continue
		for body in area.get_overlapping_bodies():
			var player := body as Player
			if player == null or player.is_dead():
				continue
			if player.is_attacking():
				player.bounce_back(area.global_position, bounce_off_speed, bounce_off_rise)
				_grace = CONTACT_GRACE
			else:
				player.hurt(area.global_position)


func _take_hit(player: Player) -> void:
	hits_left -= 1
	_flash = hit_flash_time
	_grace = CONTACT_GRACE
	homing_target.enabled = false
	player.bounce_back(weak_point.global_position, rebound_speed, rebound_rise)
	hit_taken.emit(hits_left)
	if hits_left <= 0:
		_defeat()
		return
	var new_phase := EnemyMath.boss_phase(hits_left, phase_changes)
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)
		_on_phase_changed(phase)
	else:
		_on_hit()


func _defeat() -> void:
	fighting = false
	vulnerable = false
	model.visible = true
	for area in danger_areas:
		area.set_deferred("monitoring", false)
	defeated.emit()
	_on_defeated()
	if clears_stage:
		get_tree().create_timer(defeat_time, false).timeout.connect(_clear_stage)


func _clear_stage() -> void:
	if GameState.cleared or target == null or not is_instance_valid(target) or target.is_dead():
		return
	target.set_input_enabled(false)
	GameState.clear_stage(target.rings)
