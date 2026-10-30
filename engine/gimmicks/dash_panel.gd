class_name DashPanel
extends Area3D
## A dash panel. A player on the ground who touches it is sent along its -Z axis (the way its arrows
## point) at `speed`, or faster if they already were, and can't steer for a moment.

@export var speed: float = 16.0 * PlayerPhysics.SPEED  ## Speed it sends the player off at (m/s). 30 is the classic speed booster (16 px/frame).
@export var control_lock: float = 0.25  ## Seconds the stick is ignored afterwards, so the player leaves in a straight line.


func _ready() -> void:
	# Push before the player moves this tick.
	process_physics_priority = -1
	body_entered.connect(func(_body: Node3D) -> void: set_physics_process(true))
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	# Checked every tick while touched, so a player who lands on the panel still gets sent off.
	var touching := false
	for body in get_overlapping_bodies():
		var player := body as Player
		if player:
			touching = true
			player.push_along_ground(-global_basis.z, speed, true, control_lock)
	if not touching:
		set_physics_process(false)
