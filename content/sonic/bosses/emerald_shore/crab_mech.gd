class_name CrabMech
extends Boss
## Emerald Shore's boss, fought at the end of Act 8. Eggman's ship flies in over the sea and pumps
## up a great wave, then flies off for good; Eggman isn't seen again in the stage. The crab mech
## rises out of the wave as it breaks on the beach, and the fight begins.
##
## The crab scuttles sideways to line up with the player. When they're close it sweeps a claw at
## them (jump it). Then it raises both claws and slams them down, sending tidal waves rolling across
## the beach (RollingWave: jump them, or ride them away), and sinks low with the lid over its core
## open. That's the moment to hit the core. It takes 8 hits, and at 4 and 2 hits left it gets faster
## and angrier: more waves per slam, a shorter opening, and in its last phase a charge across the
## beach before each slam.
##
## Positions are in the parent's space: put the boss scene's root at the middle of the arena, with
## the sea toward -Z.

enum Act { WAITING, INTRO, MOVE, SWEEP_WINDUP, SWEEP, SLAM_WINDUP, SLAM, SUNK, RISE, CHARGE_WINDUP, CHARGE, ROAR, DEFEATED }

const STAND_HEIGHT := 2.6  ## Height of the body's middle while standing (m)...
const SUNK_HEIGHT := 1.1  ## ...and while sunk low after a slam.
const LID_OPEN := 1.4  ## How far each half of the lid swings open (radians).
const CLAW_RAISED := 1.2  ## Shoulder pitch with the claws raised to slam (radians).
const CLAW_SLAMMED := 0.3  ## ...and slammed down, resting in the sand with the body sunk low.
const SWEEP_OUT := 1.3  ## Shoulder yaw with a claw drawn back to sweep (radians)...
const SWEEP_ACROSS := -1.05  ## ...and at the end of the sweep, across the front.
const SWEEP_TIME := 0.45  ## Seconds a sweep takes.
const SLAM_TIME := 0.15  ## Seconds for the claws to come down.
const RISE_TIME := 0.6  ## Seconds to stand back up.
const ROAR_TIME := 1.4  ## Seconds of rage at each phase change.
const WAVE_SCENE := "res://engine/gimmicks/rolling_wave.tscn"
const EXPLOSION_SCENE := "res://engine/enemies/base/explosion.tscn"
const PHASE_TINTS: Array[Color] = [Color(0.95, 0.45, 0.2), Color(1.0, 0.3, 0.1), Color(0.85, 0.08, 0.08)]

@export_group("Intro")
@export var ship: Node3D  ## Eggman's ship, which pumps up the wave and leaves.
@export var ship_pump: Node3D  ## The pump below the ship, lowered into the sea.
@export var intro_camera: Camera3D  ## Watches the intro.
@export var intro_wave: RollingWave  ## The great wave the crab rises out of.
@export var ship_start := Vector3(0.0, 30.0, -70.0)
@export var ship_hover := Vector3(0.0, 9.0, -34.0)
@export var ship_exit := Vector3(-70.0, 45.0, -90.0)
@export var pump_reach: float = 5.5  ## How far the pump lowers toward the sea (m).
@export var rise_start := Vector3(0.0, -8.0, -40.0)  ## Where the crab starts rising from, under the sea.
@export var rise_time: float = 3.1  ## Seconds to rise out of the wave onto the beach, keeping pace with it.

@export_group("Fight")
@export var move_range: float = 16.0  ## How far either side of its starting spot it scuttles (m).
@export var sweep_range: float = 6.5  ## Sweeps a claw at a player this close to its middle (m): about as far as the claws reach.
@export var move_speeds: Array[float] = [5.0, 7.5, 10.0]  ## Scuttling speed in each phase (m/s).
@export var move_times: Array[float] = [2.2, 1.8, 1.4]  ## Seconds of scuttling before each attack, per phase.
@export var sweep_windups: Array[float] = [0.7, 0.5, 0.35]  ## Seconds of warning before a sweep, per phase.
@export var slam_windups: Array[float] = [0.9, 0.7, 0.5]  ## Seconds with the claws raised before a slam, per phase.
@export var waves_per_slam: Array[int] = [1, 2, 3]
@export var wave_gaps: Array[float] = [0.7, 0.7, 0.55]  ## Seconds between the waves of one slam, per phase.
@export var windows: Array[float] = [3.5, 3.0, 2.5]  ## Seconds the core stays open after a slam, per phase.
@export var charge_speed: float = 18.0  ## Speed of the last phase's charge across the beach (m/s).
@export var wave_width: float = 56.0  ## (m)
@export var wave_height: float = 1.2  ## (m)
@export var wave_speed: float = 12.0  ## (m/s)
@export var wave_reach: float = 30.0  ## How far the waves roll, from the crab's claws (m).

var act := Act.WAITING
var act_time := 0.0

var _home := Vector3.ZERO
var _sweep_claw: Node3D
var _sweep_hurt: Area3D
var _sweep_sign := 1.0
var _swept := false
var _charged := false
var _charge_to := 0.0
var _waves_left := 0
var _wave_timer := 0.0
var _walk_cycle := 0.0
var _last_x := 0.0
var _shell_material: StandardMaterial3D
var _player_camera: Camera3D
var _watch_ship := false  # The intro camera follows the ship; afterwards, the crab.
var _camera_focus := Vector3.ZERO

@onready var _body: Node3D = %Body
@onready var _shell: MeshInstance3D = %Shell
@onready var _lid_left: Node3D = %LidLeft
@onready var _lid_right: Node3D = %LidRight
@onready var _claw_left: Node3D = %ClawLeft
@onready var _claw_right: Node3D = %ClawRight
@onready var _claw_hurt_left: Area3D = %ClawHurtLeft
@onready var _claw_hurt_right: Area3D = %ClawHurtRight
@onready var _shell_hurt: Area3D = %ShellHurt
@onready var _legs: Node3D = %Legs


func _ready() -> void:
	super()
	_home = position
	_last_x = position.x
	# Its own copy, so the phase colour doesn't change every crab sharing the scene's material.
	_shell_material = (_shell.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	_shell.material_override = _shell_material
	_claw_hurt_left.monitoring = false
	_claw_hurt_right.monitoring = false
	_set_lid(0.0)
	visible = false
	if ship:
		ship.visible = false


# --- Intro --------------------------------------------------------------------------------

func begin(player: Player) -> void:
	target = player
	_play_intro()


func _play_intro() -> void:
	act = Act.INTRO
	target.set_input_enabled(false)
	_player_camera = get_viewport().get_camera_3d()
	if intro_camera:
		intro_camera.make_current()
	var pump_height := ship_pump.position.y if ship_pump else 0.0
	if ship:
		ship.position = ship_start
		ship.visible = true
		_watch_ship = true
		_camera_focus = ship.global_position
		var arrive := create_tween()
		arrive.tween_property(ship, "position", ship_hover, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		if ship_pump:
			arrive.tween_property(ship_pump, "position:y", pump_height - pump_reach, 0.5).set_ease(Tween.EASE_IN)
		await arrive.finished
	if intro_wave:
		intro_wave.roll()
	if ship:
		var leave := create_tween()
		leave.tween_interval(0.4)
		if ship_pump:
			leave.tween_property(ship_pump, "position:y", pump_height, 0.3)
		leave.tween_property(ship, "position", ship_exit, 1.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		leave.tween_callback(ship.hide)
	position = rise_start
	visible = true
	get_tree().create_timer(0.5, false).timeout.connect(func() -> void: _watch_ship = false)
	var rise := create_tween()
	rise.tween_property(self, "position", _home, rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await rise.finished
	await _shake(0.8, 0.12)
	if is_instance_valid(_player_camera):
		_player_camera.make_current()
	target.set_input_enabled(true)
	start_fight()
	_set_act(Act.MOVE)


# --- The fight ------------------------------------------------------------------------------

func _fight(delta: float) -> void:
	act_time += delta
	_send_waves(delta)
	match act:
		Act.MOVE:
			_scuttle(_lined_up_x(), move_speeds[phase], delta)
			if act_time >= move_times[phase]:
				_choose_attack()
		Act.SWEEP_WINDUP:
			var drawn := clampf(act_time / sweep_windups[phase], 0.0, 1.0)
			_sweep_claw.rotation = Vector3(0.3 * drawn, SWEEP_OUT * _sweep_sign * drawn, 0.0)
			if act_time >= sweep_windups[phase]:
				_sweep_hurt.monitoring = true
				_set_act(Act.SWEEP)
		Act.SWEEP:
			var swept := clampf(act_time / SWEEP_TIME, 0.0, 1.0)
			_sweep_claw.rotation = Vector3(lerpf(0.3, -0.1, swept), lerpf(SWEEP_OUT, SWEEP_ACROSS, swept) * _sweep_sign, 0.0)
			if act_time >= SWEEP_TIME + 0.35:
				_sweep_hurt.monitoring = false
				_sweep_claw.rotation = Vector3.ZERO
				_swept = true
				_set_act(Act.MOVE)
				act_time = move_times[phase] - 0.3  # A short pause, then straight on to the slam.
		Act.SLAM_WINDUP:
			var raised := clampf(act_time / 0.35, 0.0, 1.0)
			_set_claw_pitch(CLAW_RAISED * raised)
			_body.position.y = STAND_HEIGHT + 0.3 * raised
			if act_time >= slam_windups[phase]:
				_claw_hurt_left.monitoring = true
				_claw_hurt_right.monitoring = true
				_set_act(Act.SLAM)
		Act.SLAM:
			var down := clampf(act_time / SLAM_TIME, 0.0, 1.0)
			_set_claw_pitch(lerpf(CLAW_RAISED, CLAW_SLAMMED, down))
			_body.position.y = lerpf(STAND_HEIGHT + 0.3, SUNK_HEIGHT, down)
			if down >= 1.0:
				_claw_hurt_left.monitoring = false
				_claw_hurt_right.monitoring = false
				_waves_left = waves_per_slam[phase]
				_wave_timer = 0.0
				_open_up()
		Act.SUNK:
			_set_lid(clampf(act_time / 0.3, 0.0, 1.0))
			if act_time >= windows[phase]:
				_close_up(Act.RISE)
		Act.RISE:
			_stand_up(delta)
			if act_time >= RISE_TIME:
				_swept = false
				_charged = false
				_set_act(Act.MOVE)
		Act.CHARGE_WINDUP:
			var start := _home.x - move_range if _charge_to > _home.x else _home.x + move_range
			_scuttle(start, move_speeds[phase] * 1.5, delta)
			if absf(position.x - start) < 0.1 and act_time >= 0.8:
				_set_act(Act.CHARGE)
		Act.CHARGE:
			_scuttle(_charge_to, charge_speed, delta)
			if absf(position.x - _charge_to) < 0.1:
				_charged = true
				_set_act(Act.SLAM_WINDUP)
		Act.ROAR:
			_stand_up(delta)
			_body.position.x = sin(act_time * 70.0) * 0.12
			if act_time >= ROAR_TIME:
				_body.position.x = 0.0
				_set_act(Act.MOVE)


func _process(delta: float) -> void:
	var moved := absf(position.x - _last_x)
	_last_x = position.x
	if delta > 0.0 and moved > 1e-4:
		_walk_cycle += moved * 2.2
	for i in _legs.get_child_count():
		var leg := _legs.get_child(i) as Node3D
		var side := 1.0 if i % 2 == 0 else -1.0
		leg.rotation.x = sin(_walk_cycle + i * 1.7) * 0.35 * side
	if act == Act.INTRO and intro_camera and intro_camera.current:
		var goal := ship.global_position if _watch_ship and ship else global_position + Vector3.UP * 2.5
		_camera_focus = _camera_focus.lerp(goal, 1.0 - exp(-3.0 * delta))
		intro_camera.look_at(_camera_focus, Vector3.UP)


func _choose_attack() -> void:
	if phase >= 2 and not _charged:
		var player_x := _to_parent(target.global_position).x
		_charge_to = _home.x + move_range if player_x >= position.x else _home.x - move_range
		_set_act(Act.CHARGE_WINDUP)
	elif not _swept and _flat_distance_to_player() < sweep_range:
		var right := to_local(target.global_position).x > 0.0
		_sweep_claw = _claw_right if right else _claw_left
		_sweep_hurt = _claw_hurt_right if right else _claw_hurt_left
		_sweep_sign = -1.0 if right else 1.0
		_set_act(Act.SWEEP_WINDUP)
	else:
		_set_act(Act.SLAM_WINDUP)


## After a slam: sinks low with the core open to a hit.
func _open_up() -> void:
	vulnerable = true
	_shell_hurt.monitoring = false
	_set_act(Act.SUNK)


## Closes the core and moves on to `next`.
func _close_up(next: Act) -> void:
	vulnerable = false
	_set_lid(0.0)
	_shell_hurt.monitoring = true
	_set_act(next)


func _stand_up(delta: float) -> void:
	_body.position.y = move_toward(_body.position.y, STAND_HEIGHT, (STAND_HEIGHT - SUNK_HEIGHT) / RISE_TIME * delta)
	_set_claw_pitch(move_toward(_claw_left.rotation.x, 0.0, absf(CLAW_SLAMMED) / RISE_TIME * delta))


func _send_waves(delta: float) -> void:
	if _waves_left <= 0:
		return
	_wave_timer -= delta
	if _wave_timer > 0.0:
		return
	_wave_timer = wave_gaps[phase]
	_waves_left -= 1
	var wave := (load(WAVE_SCENE) as PackedScene).instantiate() as RollingWave
	wave.width = wave_width
	wave.height = wave_height
	wave.speed = wave_speed
	wave.push_speed = wave_speed + 1.0
	wave.reach = wave_reach
	wave.rolling = false
	wave.free_when_done = true
	get_parent().add_child(wave)
	# From the claws' line, rolling toward the beach (+Z), across the whole arena.
	wave.position = Vector3(_home.x, 0.0, position.z + 3.5)
	wave.rotation = Vector3(0.0, PI, 0.0)
	wave.roll()


# --- Boss hooks ---------------------------------------------------------------------------

func _on_hit() -> void:
	var flinch := create_tween()
	flinch.tween_property(_body, "position:y", SUNK_HEIGHT - 0.25, 0.08)
	flinch.tween_property(_body, "position:y", SUNK_HEIGHT, 0.2)


func _on_phase_changed(new_phase: int) -> void:
	_shell_material.albedo_color = PHASE_TINTS[mini(new_phase, PHASE_TINTS.size() - 1)]
	_waves_left = 0
	_close_up(Act.ROAR)


func _on_defeated() -> void:
	act = Act.DEFEATED
	_set_lid(0.0)
	_shell_hurt.monitoring = false
	_waves_left = 0
	var blasts := create_tween().set_loops(16)
	blasts.tween_callback(_explode)
	blasts.tween_interval(0.15)
	var collapse := create_tween()
	collapse.tween_interval(1.2)
	collapse.tween_property(_body, "position:y", 0.6, 1.0).set_ease(Tween.EASE_IN)
	collapse.parallel().tween_property(_body, "rotation:z", 0.25, 1.0)


func _explode() -> void:
	var explosion := (load(EXPLOSION_SCENE) as PackedScene).instantiate() as Explosion
	explosion.size = randf_range(1.8, 3.2)
	get_parent().add_child(explosion)
	explosion.global_position = _body.global_position + Vector3(randf_range(-2.6, 2.6), randf_range(-0.8, 1.4), randf_range(-2.0, 2.0))


# --- Helpers ------------------------------------------------------------------------------

func _set_act(next: Act) -> void:
	act = next
	act_time = 0.0


func _scuttle(goal_x: float, speed: float, delta: float) -> void:
	position.x = move_toward(position.x, goal_x, speed * delta)


## Where along its line the crab would be right in front of the player, within its range.
func _lined_up_x() -> float:
	return clampf(_to_parent(target.global_position).x, _home.x - move_range, _home.x + move_range)


func _flat_distance_to_player() -> float:
	var offset := _to_parent(target.global_position) - position
	return Vector2(offset.x, offset.z).length()


func _to_parent(point: Vector3) -> Vector3:
	var parent := get_parent_node_3d()
	return parent.to_local(point) if parent else point


func _set_claw_pitch(pitch: float) -> void:
	_claw_left.rotation.x = pitch
	_claw_right.rotation.x = pitch


## 0 shut, 1 wide open.
func _set_lid(open: float) -> void:
	_lid_left.rotation.z = open * LID_OPEN
	_lid_right.rotation.z = -open * LID_OPEN


func _shake(seconds: float, amount: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		_body.position.x = randf_range(-amount, amount)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	_body.position.x = 0.0
