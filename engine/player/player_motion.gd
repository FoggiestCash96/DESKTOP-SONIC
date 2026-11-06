class_name PlayerMotion
extends RefCounted
## Movement math for the player controller, kept free of nodes so the unit tests can call it.
## Anything that changes over time takes the tick length, so results are the same at any tick rate.

const AIR_DRAG_MAX_RISE := 4.0 * PlayerPhysics.SPEED  ## Air drag only applies while rising slower than this (m/s).
const AIR_DRAG_MIN_SPEED := 0.125 * PlayerPhysics.SPEED  ## ...and moving horizontally at least this fast (m/s).
const AIR_DRAG_KEEP_PER_FRAME := 1.0 - 1.0 / 32.0  ## Share of horizontal speed kept per classic frame (1/60 s).
const SPIN_CHARGE_KEEP_PER_FRAME := 1.0 - 1.0 / 32.0  ## Share of spin dash charge kept per classic frame (1/60 s).
const LOST_RINGS_PER_CIRCLE := 16  ## Scattered rings fly out in circles of this many, as in the classic games.
const LOST_RING_STEEP := 60.0  ## Alternate scattered rings fly out this many degrees above the horizontal...
const LOST_RING_SHALLOW := 30.0  ## ...and the others this many.
const HOMING_OVERHEAD := 1.0  ## A homing target closer than this horizontally (m) is straight above or below, and counts as in front.
const LIGHT_DASH_TOUCH := 0.25  ## A ring closer than this to a light speed dash (m) is the one being collected now.


## Ground speed after one tick of running. `input_strength` (0 to 1) is how far the stick is
## pushed in the direction of travel.
static func run_speed(speed: float, input_strength: float, physics: PlayerPhysics, delta: float) -> float:
	if input_strength <= 0.0:
		return move_toward(speed, 0.0, physics.frc * delta)
	var target := physics.top * input_strength
	if speed < target:
		return minf(speed + physics.acc * delta, target)
	if input_strength < 1.0:
		# A partly pushed stick eases back down to its slower target speed.
		return maxf(speed - physics.frc * delta, target)
	# Full input above top speed keeps the momentum, as in the classic games.
	return speed


## Ground speed after one tick of braking against the direction of travel. A negative result
## means the player stopped and turned around: it is the speed in the new direction, negated.
static func brake_speed(speed: float, physics: PlayerPhysics, delta: float) -> float:
	var braked := speed - physics.dec * delta
	if braked <= 0.0:
		return -physics.turnaround_speed
	return braked


## Turn rate in radians per second: turn_rate_low at rest, easing linearly to turn_rate_high at
## top speed and above.
static func turn_rate(speed: float, physics: PlayerPhysics) -> float:
	var t := clampf(speed / physics.top, 0.0, 1.0) if physics.top > 0.0 else 1.0
	return deg_to_rad(lerpf(physics.turn_rate_low, physics.turn_rate_high, t))


## `heading` rotated toward `wish` around `up` by at most `max_angle` radians. Both directions
## are unit vectors perpendicular to `up`.
static func turn_toward(heading: Vector3, wish: Vector3, up: Vector3, max_angle: float) -> Vector3:
	var angle := heading.signed_angle_to(wish, up)
	if absf(angle) <= max_angle:
		return wish
	return heading.rotated(up, signf(angle) * max_angle)


## Vertical speed after one tick of gravity, never falling faster than max_fall.
static func fall_speed(vertical: float, physics: PlayerPhysics, delta: float) -> float:
	return maxf(vertical - physics.grv * delta, -physics.max_fall)


## Variable jump height: while jump is not held, upward speed is capped at jmp_release_cap.
static func release_cap(vertical: float, physics: PlayerPhysics) -> float:
	return minf(vertical, physics.jmp_release_cap)


## Horizontal velocity after one tick of air control. Input steers and speeds the player up to
## top speed, but never drains momentum gained above it.
static func air_velocity(horizontal: Vector3, wish: Vector3, physics: PlayerPhysics, delta: float) -> Vector3:
	if wish == Vector3.ZERO:
		return horizontal
	var limit := maxf(horizontal.length(), physics.top)
	return (horizontal + wish * physics.air_acc * delta).limit_length(limit)


## Classic air drag: near the top of a jump, horizontal speed bleeds off by 1/32 per 60 fps frame.
static func air_drag(horizontal: Vector3, vertical: float, delta: float) -> Vector3:
	if vertical <= 0.0 or vertical >= AIR_DRAG_MAX_RISE:
		return horizontal
	if horizontal.length() < AIR_DRAG_MIN_SPEED:
		return horizontal
	return horizontal * pow(AIR_DRAG_KEEP_PER_FRAME, delta * PlayerPhysics.CLASSIC_FPS)


## The pull of gravity along a surface with this normal, as a vector along the surface pointing
## downhill. Its length is the sine of the slope: 0 on flat ground and ceilings, 1 on a wall.
static func downhill(normal: Vector3) -> Vector3:
	return Vector3.DOWN + normal * normal.dot(Vector3.UP)


## Whether a slope is steep enough to drag a runner who is standing still: classic games let you
## stand on gentle slopes because friction wins there.
static func slope_beats_friction(normal: Vector3, physics: PlayerPhysics) -> bool:
	return downhill(normal).length() * physics.slp > physics.frc


## Angle between a surface and flat ground, in degrees: 0 for floors, 90 for walls, 180 for ceilings.
static func steepness(normal: Vector3) -> float:
	return rad_to_deg(normal.angle_to(Vector3.UP))


## Whether a player this slow on a surface this steep starts to slip.
static func slips(speed: float, normal: Vector3, physics: PlayerPhysics) -> bool:
	return speed < physics.slip_threshold and steepness(normal) > physics.slip_angle


## Whether the player drops off an overhang. Past vertical, gravity pulls them away from the
## surface, and only speed and ground_magnetism hold them on. At the classic slip speed they hold
## on even upside down; slower than that, steeper overhangs need more speed.
static func falls_off(speed: float, normal: Vector3, physics: PlayerPhysics) -> bool:
	var pull := physics.grv * -normal.dot(Vector3.UP)
	if pull <= 0.0:
		return false
	var hold := physics.grv * pow(speed / physics.slip_threshold, 2.0) + physics.ground_magnetism
	return hold < pull


## The part of `velocity` that runs along a surface with this normal, used when landing.
static func along_surface(velocity: Vector3, normal: Vector3) -> Vector3:
	return velocity - normal * normal.dot(velocity)


## Ground speed after one tick of rolling: roll friction always applies, plus roll_dec when braking.
static func roll_speed(speed: float, braking: bool, physics: PlayerPhysics, delta: float) -> float:
	var slowdown := physics.roll_frc + (physics.roll_dec if braking else 0.0)
	return maxf(speed - slowdown * delta, 0.0)


## Launch speed of a spin dash: the classic 8 + floor(charge) / 2 px/frame.
static func spin_dash_speed(charge: float, physics: PlayerPhysics) -> float:
	return physics.spin_dash_speed + floorf(charge) * physics.spin_dash_charge_speed


## Spin dash charge after one tick: it bleeds off by 1/32 per 60 fps frame, as in the classic games.
static func decay_charge(charge: float, delta: float) -> float:
	return charge * pow(SPIN_CHARGE_KEEP_PER_FRAME, delta * PlayerPhysics.CLASSIC_FPS)


## Velocity of the knockback from a hit: `away` (a horizontal unit vector pointing away from what
## hurt the player) at hurt_speed, plus hurt_rise upward.
static func hurt_velocity(away: Vector3, physics: PlayerPhysics) -> Vector3:
	return away * physics.hurt_speed + Vector3.UP * physics.hurt_rise


## Launch velocities for the rings a hit knocks loose: one per ring, at most max_lost_rings. As in
## the classic games the first circle of 16 flies out fast and the rest slowly; in 3D each circle
## fans out all the way around the player, alternately steep and shallow.
static func ring_scatter(count: int, physics: PlayerPhysics) -> Array[Vector3]:
	var velocities: Array[Vector3] = []
	for i in mini(count, physics.max_lost_rings):
		var later := i >= LOST_RINGS_PER_CIRCLE
		var speed := physics.lost_ring_speed_slow if later else physics.lost_ring_speed_fast
		# Later circles sit half a step round from the first, so the rings don't overlap.
		var around := TAU * (float(i % LOST_RINGS_PER_CIRCLE) + (0.5 if later else 0.0)) / LOST_RINGS_PER_CIRCLE
		var up := deg_to_rad(LOST_RING_STEEP if i % 2 == 0 else LOST_RING_SHALLOW)
		velocities.append(Vector3(cos(around) * cos(up), sin(up), sin(around) * cos(up)) * speed)
	return velocities


## Which of CharacterModel.POSES a player's model shows, in order of priority: dead, hurt, curled
## into a ball, in the air (still rising from a spring, or falling), stopped after the goal,
## skidding, pushing a wall, and otherwise the run cycle.
static func pose(dead: bool, hurt: bool, curled: bool, grounded: bool, sprung: bool, finished: bool, braking: bool, pushing: bool) -> StringName:
	if dead:
		return &"death"
	if hurt:
		return &"hurt"
	if curled:
		return &"ball"
	if not grounded:
		return &"spring" if sprung else &"fall"
	if finished:
		return &"victory"
	if braking:
		return &"skid"
	if pushing:
		return &"push"
	return &"ground"


## `velocity` after a push along `direction` (a unit vector) by `amount` (m/s), as from moving
## water: it adds speed along the push, but never past `max_speed` along it. Against the push it
## slows the player down.
static func pushed(velocity: Vector3, direction: Vector3, max_speed: float, amount: float) -> Vector3:
	var along := velocity.dot(direction)
	if along >= max_speed:
		return velocity
	return velocity + direction * minf(amount, max_speed - along)


## Whether a homing attack target at `offset` from the player is in reach: no farther than
## `reach`, and within `cone_degrees` (both sides together) of `aim` on the horizontal plane.
static func in_homing_reach(offset: Vector3, aim: Vector3, reach: float, cone_degrees: float) -> bool:
	if offset.length() > reach:
		return false
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length() < HOMING_OVERHEAD:
		return true
	var flat_aim := Vector3(aim.x, 0.0, aim.z)
	if flat_aim.length_squared() < 1e-6:
		return false
	return flat.normalized().dot(flat_aim.normalized()) >= cos(deg_to_rad(cone_degrees * 0.5)) - 1e-6


## Horizontal velocity after an air dash along `direction` (a horizontal unit vector): `speed`
## that way, or the player's own speed along it if that's faster. Any sideways drift is dropped.
static func air_dash(horizontal: Vector3, direction: Vector3, speed: float) -> Vector3:
	return direction * maxf(speed, horizontal.dot(direction))


## Vertical speed after destroying an enemy in the air, as in the classic games. Falling onto it
## from above bounces the player back up at the speed they fell. Rising, or level with its middle
## or lower, they are only slowed by `slowdown`.
static func enemy_rebound(vertical: float, player_height: float, enemy_height: float, slowdown: float) -> float:
	if vertical > 0.0:
		return vertical - slowdown
	if player_height <= enemy_height:
		return vertical + slowdown
	return -vertical


## The boost gauge (0 to 100) after adding `amount` (negative to use some).
static func boost_fill(gauge: float, amount: float) -> float:
	return clampf(gauge + amount, 0.0, 100.0)


## Velocity of a quickstep: sideways across `heading` on the surface with normal `up`, to the right
## for `side` 1 and the left for -1, fast enough to cover quickstep_distance in quickstep_time.
static func quickstep_velocity(heading: Vector3, up: Vector3, side: float, physics: PlayerPhysics) -> Vector3:
	var right := heading.cross(up)
	if right.length_squared() < 1e-6:
		return Vector3.ZERO
	return right.normalized() * side * physics.quickstep_distance / maxf(physics.quickstep_time, 0.001)


## Movement values with speed shoes on: a copy of `physics` with acc, frc, top, air_acc and
## roll_frc multiplied by speed_shoes_factor, as the classic shoes double them.
static func with_speed_shoes(physics: PlayerPhysics) -> PlayerPhysics:
	var fast := physics.duplicate() as PlayerPhysics
	var factor := physics.speed_shoes_factor
	fast.acc *= factor
	fast.frc *= factor
	fast.top *= factor
	fast.air_acc *= factor
	fast.roll_frc *= factor
	return fast


## Movement values underwater: a copy of `physics` with acc, dec, frc, top, air_acc, roll_frc,
## boost_speed and the stomp, drop dash and peel out speeds multiplied by water_factor, and the
## lighter gravity, lower jump and gentler knockback of water_grv, water_jmp,
## water_jmp_release_cap and water_hurt_gravity, as the classic games swap them in underwater.
static func underwater(physics: PlayerPhysics) -> PlayerPhysics:
	var wet := physics.duplicate() as PlayerPhysics
	var factor := physics.water_factor
	wet.acc *= factor
	wet.dec *= factor
	wet.frc *= factor
	wet.top *= factor
	wet.air_acc *= factor
	wet.roll_frc *= factor
	wet.boost_speed *= factor
	wet.stomp_speed *= factor
	wet.drop_dash_speed *= factor
	wet.drop_dash_max *= factor
	wet.peel_out_speed *= factor
	wet.grv = physics.water_grv
	wet.jmp = physics.water_jmp
	wet.jmp_release_cap = physics.water_jmp_release_cap
	wet.hurt_gravity = physics.water_hurt_gravity
	return wet


## Velocity on falling into water: the water takes away most of it, keeping water_entry_horizontal
## of the horizontal part and water_entry_vertical of the vertical part.
static func water_entry(velocity: Vector3, physics: PlayerPhysics) -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z) * physics.water_entry_horizontal
	return horizontal + Vector3.UP * velocity.y * physics.water_entry_vertical


## Velocity on leaving the water: rising speed is multiplied by water_exit_boost (up to max_fall),
## so a jump from underwater carries the player out of it.
static func water_exit(velocity: Vector3, physics: PlayerPhysics) -> Vector3:
	if velocity.y <= 0.0:
		return velocity
	return Vector3(velocity.x, minf(velocity.y * physics.water_exit_boost, physics.max_fall), velocity.z)


## The number the drowning countdown shows with `air` seconds of air left: 5 when `countdown`
## seconds are left, one less every two seconds after that, 0 in the last two. -1 before it starts.
static func drown_count(air: float, countdown: float) -> int:
	if air > countdown or air <= 0.0:
		return -1
	return clampi(ceili(air / 2.0) - 1, 0, 5)


## Whether the air ran down past one of the warning chimes (25, 20 and 15 seconds left) between
## `before` and `after` seconds.
static func air_warning(before: float, after: float) -> bool:
	for warning: float in [25.0, 20.0, 15.0]:
		if before > warning and after <= warning:
			return true
	return false


## Grinding speed after `delta` seconds on a rail running along `direction` (a unit vector, the way
## the player is going): gravity speeds them up downhill (slp_roll_down) and slows them uphill
## (slp_roll_up), as when rolling, and grind_frc slows them a little, though never below
## grind_min_speed: only a climb can stop a grind (and send it back down).
static func grind_speed(speed: float, direction: Vector3, physics: PlayerPhysics, delta: float) -> float:
	var climb := direction.dot(Vector3.UP)
	var slope := physics.slp_roll_up if climb > 0.0 else physics.slp_roll_down
	speed -= slope * climb * delta
	if speed > physics.grind_min_speed:
		speed = maxf(speed - physics.grind_frc * delta, physics.grind_min_speed)
	return speed


## A drop dash's launch speed, the classic way. `along` is the speed the player was already
## going along the launch direction (negative against it): going that way they keep a quarter of
## it on top of drop_dash_speed, up to drop_dash_max; against it they launch at drop_dash_speed.
static func drop_dash_speed(along: float, physics: PlayerPhysics) -> float:
	if along > 0.0:
		return minf(along * 0.25 + physics.drop_dash_speed, physics.drop_dash_max)
	return physics.drop_dash_speed


## `heading` after `delta` seconds of a drift turning to `side` (1 right, -1 left) on a surface
## with normal `normal`: drift_turn_rate with the stick pushed fully into the turn (`into` 1), half
## that with it straight or away (`into` 0 or less).
static func drift_heading(heading: Vector3, normal: Vector3, side: float, into: float, physics: PlayerPhysics, delta: float) -> Vector3:
	var strength := clampf(0.5 + 0.5 * into, 0.5, 1.0)
	var angle := deg_to_rad(physics.drift_turn_rate) * strength * delta
	return heading.rotated(normal.normalized(), -angle * signf(side)).normalized()


## Which of `rings` (positions) a light speed dash at `from`, going `direction`, goes to next: the
## nearest within `reach` that isn't behind it, nor the one being touched now (closer than
## LIGHT_DASH_TOUCH). With `direction` zero, to start a dash, the nearest within reach. Returns
## its index, or -1 with none.
static func light_dash_next(from: Vector3, direction: Vector3, rings: Array[Vector3], reach: float) -> int:
	var best := -1
	var best_distance := INF
	for i in rings.size():
		var offset := rings[i] - from
		var distance := offset.length()
		if distance > reach or distance >= best_distance:
			continue
		if direction != Vector3.ZERO and (distance < LIGHT_DASH_TOUCH or offset.dot(direction) < 0.0):
			continue
		best = i
		best_distance = distance
	return best


## The kick off a wall-jump panel facing out along `normal`: wall_jump_out away from it, on the
## horizontal plane, and wall_jump_up up.
static func wall_jump_velocity(normal: Vector3, physics: PlayerPhysics) -> Vector3:
	var out := Vector3(normal.x, 0.0, normal.z)
	if out.length_squared() < 1e-6:
		out = Vector3.ZERO
	else:
		out = out.normalized()
	return out * physics.wall_jump_out + Vector3.UP * physics.wall_jump_up
