class_name BossArena
extends Area3D
## Where a boss fight happens. The first time a player enters, it raises its barriers (the solid
## body %Barriers, kept switched off and hidden until then) to keep them in, calls begin() on
## `boss` and starts `music`. Beating the boss fades the music out.

@export var boss: Boss
@export var music: AudioStream  ## The fight's music. Empty keeps the stage's.

var started := false

@onready var _barriers: StaticBody3D = %Barriers


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_raise_barriers(false)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or player.is_dead() or started:
		return
	started = true
	# Shapes can't switch on while the physics server is reporting this overlap.
	_raise_barriers.call_deferred(true)
	if music:
		Music.play(music)
	if boss:
		boss.defeated.connect(Music.stop.bind(2.0), CONNECT_ONE_SHOT)
		boss.begin(player)


func _raise_barriers(on: bool) -> void:
	_barriers.visible = on
	for shape in _barriers.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = not on
