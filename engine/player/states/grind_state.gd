class_name GrindState
extends PlayerState
## Grinding along a GrindRail. Gravity speeds the player up downhill and slows them uphill (as when
## rolling), a little friction always slows them, and pushing the stick the way they're going
## speeds them up to top speed. The boost holds its speed here too. Jump leaves the rail with a
## jump, a quickstep hops to a rail beside this one, and the end of the rail throws them on into
## the air. Something in the way knocks them off.

const BLOCKED := 0.3  ## Ending up this far from the rail after a move means something got in the way (m).

var rail: GrindRail
var offset := 0.0  ## How far along the rail the player is (m).
var direction := 1.0  ## 1 grinding toward the rail's end, -1 toward its start.

var _hop_offset := Vector3.ZERO  # Where a hop to another rail started, from the new rail.
var _hop_timer := 0.0  # Seconds of the hop left.


func label() -> String:
	return "GRIND"


## Starts grinding `new_rail` at `at` metres along it, `toward` its end (1) or start (-1).
func attach(new_rail: GrindRail, at: float, toward: float) -> void:
	rail = new_rail
	offset = at
	direction = toward
	_hop_timer = 0.0


func enter(_previous: PlayerState) -> void:
	player.set_ball(false)
	player.ground_normal = Vector3.UP
	player.up_direction = Vector3.UP
	Sfx.play(&"grind")


func exit() -> void:
	rail = null
	_hop_timer = 0.0


## The way the player is grinding, as a unit vector.
func motion_direction() -> Vector3:
	return rail.tangent_at(offset) * direction


func tick(delta: float) -> void:
	var physics := player.physics
	if not is_instance_valid(rail):
		player.change_state(player.air_state)
		return
	var along := motion_direction()
	if player.wants_jump():
		player.leave_rail(true)
		return
	if player.quickstep_pressed != 0 and _hop_timer <= 0.0:
		_hop(float(player.quickstep_pressed))
	var speed := PlayerMotion.grind_speed(player.ground_speed, along, physics, delta)
	if player.wish.dot(along) > 0.3 and speed < physics.top:
		speed = minf(speed + physics.acc * delta, physics.top)
	if player.boosting:
		speed = maxf(speed, physics.boost_speed)
	if speed < 0.0:
		# Slid to a stop on the way up: back down it goes.
		direction = -direction
		speed = -speed
	player.ground_speed = minf(speed, physics.max_ground_speed)
	offset += direction * player.ground_speed * delta
	if offset < 0.0 or offset > rail.length():
		player.leave_rail(false)
		return
	var target := rail.top_at(offset)
	if _hop_timer > 0.0:
		_hop_timer = maxf(_hop_timer - delta, 0.0)
		target += _hop_offset * (_hop_timer / physics.grind_switch_time)
	player.velocity = (target - player.global_position) / delta
	player.heading = motion_direction()
	player.turn_upright(delta, false)


func after_move(_delta: float) -> void:
	if rail and _hop_timer <= 0.0 and player.global_position.distance_to(rail.top_at(offset)) > BLOCKED:
		player.leave_rail(false)


## A quickstep while grinding: hops to the nearest other rail on that side (`side` 1 right, -1
## left), within grind_switch_reach, keeping the way and speed the player is going.
func _hop(side: float) -> void:
	var along := motion_direction()
	var right := along.cross(Vector3.UP)
	if right.length_squared() < 1e-6:
		return
	right = right.normalized() * side
	var here := rail.top_at(offset)
	var best: GrindRail = null
	var best_offset := 0.0
	var best_distance := INF
	for node in player.get_tree().get_nodes_in_group(GrindRail.GROUP):
		var other := node as GrindRail
		if other == null or other == rail:
			continue
		var aim := here + right * player.physics.grind_switch_reach * 0.6
		if not other.near(aim, player.physics.grind_switch_reach):
			continue
		var at := other.closest_offset(aim)
		var point := other.top_at(at)
		var sideways := (point - here).dot(right)
		var distance := point.distance_to(here)
		if sideways > 0.5 and distance <= player.physics.grind_switch_reach and distance < best_distance:
			best = other
			best_offset = at
			best_distance = distance
	if best == null:
		return
	_hop_offset = player.global_position - best.top_at(best_offset)
	_hop_timer = player.physics.grind_switch_time
	direction = 1.0 if best.tangent_at(best_offset).dot(along) >= 0.0 else -1.0
	rail = best
	offset = best_offset
	Sfx.play(&"quickstep")
