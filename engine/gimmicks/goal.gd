class_name Goal
extends Area3D
## The end of an act: a giant ring to run through. Heading for it, the player is eased onto the line
## through its middle, from `funnel` metres out, and just before it they leap, topping out as they
## pass through, so they go cleanly through the ring even running along the ground. Then the clock
## stops and the controls go while they skid to a stop; the results show, and the stage moves on.
## The gate, `width` metres wide across the ring's plane, ends the act for anyone who passes the ring
## some other way, such as over it. Turn the goal so its -Z axis points the way the player runs.

const IDLE_SPIN := 1.6  ## The emblem in the middle turns this fast (radians per second)...
const FINISH_SPIN := 28.0  ## ...and this fast as the act ends, slowing back down over FINISH_TIME.
const FINISH_TIME := 2.5  ## Seconds the flourish at the end takes.
const BOB_HEIGHT := 0.12  ## How far the ring floats up and down (m)...
const BOB_SPEED := 1.6  ## ...and how fast (radians per second).
const LEAD_SPEED := 1.0  ## Players heading for the ring at least this fast (m/s) are eased onto its middle.

@export var width: float = 18.0  ## Width of the gate across the ring's plane (m): at least the course's.
@export var funnel: float = 30.0  ## From this far out (m), players heading for the ring are eased onto the line through its middle.
@export var leap_height: float = 0.9  ## How high the leap through the ring rises (m): enough for a running player's feet to clear its lower edge.

var _spin := IDLE_SPIN  # How fast the emblem turns now (radians per second).
var _time := 0.0
var _ring_height := 0.0

@onready var _shape: CollisionShape3D = %Shape
@onready var _ring: Node3D = %Ring
@onready var _emblem: Node3D = %Emblem
@onready var _sparkles: GPUParticles3D = %Sparkles


func _ready() -> void:
	ModelSkin.apply(self, ArtBank.model(&"goal"))
	var gate := (_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	gate.size.x = width
	_shape.shape = gate
	_ring_height = _ring.position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_ring.position.y = _ring_height + BOB_HEIGHT * sin(_time * BOB_SPEED)
	_emblem.rotate_y(_spin * delta)


func _physics_process(delta: float) -> void:
	if GameState.cleared:
		set_physics_process(false)
		return
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player and not player.is_dead():
			_lead(player, delta)


## Eases a player heading for the ring onto the line through its middle, and just before it, if
## they're on the ground, sends them leaping through it.
func _lead(player: Player, delta: float) -> void:
	var local := global_transform.affine_inverse() * player.global_position
	var through := global_basis.z.normalized() * (-signf(local.z) if local.z != 0.0 else -1.0)
	var speed := player.velocity.dot(through)
	var distance := absf(local.z)
	if speed < LEAD_SPEED or distance > funnel or local.y < -4.0 or local.y > _shape.position.y * 2.0:
		return
	if absf(local.x) > width * 0.5 + distance:
		return  # Off to the side, beyond a funnel that narrows to the gate.
	var across := global_basis.x.normalized()
	var step := minf(absf(local.x), speed * player.physics.lane_pull_ratio * delta)
	if step > 1e-4:
		player.nudge(-across * signf(local.x) * step)
	if player.is_grounded() and distance <= speed * GimmickMath.time_to_rise(leap_height, player.physics.grv):
		var up := GimmickMath.leap_speed(distance, speed, player.physics.grv)
		_finish(player, through * speed + Vector3.UP * up)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player and not player.is_dead():
		_finish(player, Vector3.ZERO)


## Ends the act, with the player leaping off at `leap` (unless that's zero).
func _finish(player: Player, leap: Vector3) -> void:
	if GameState.cleared:
		return
	player.finish()
	GameState.clear_stage(player.rings)
	Sfx.play(&"goal")
	if leap != Vector3.ZERO:
		player.launch(leap, 0.0)
	_sparkles.restart()
	_spin = FINISH_SPIN
	create_tween().tween_property(self, "_spin", IDLE_SPIN, FINISH_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var pulse := create_tween()
	pulse.tween_property(_ring, "scale", Vector3.ONE * 1.12, 0.15).set_ease(Tween.EASE_OUT)
	pulse.tween_property(_ring, "scale", Vector3.ONE, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
