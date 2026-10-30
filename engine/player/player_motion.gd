class_name PlayerMotion
extends RefCounted
## Movement math for the player controller, kept free of nodes so the unit tests can call it.
## Every function takes the tick length, so results are the same at any tick rate.

const AIR_DRAG_MAX_RISE := 4.0 * PlayerPhysics.SPEED  ## Air drag only applies while rising slower than this (m/s).
const AIR_DRAG_MIN_SPEED := 0.125 * PlayerPhysics.SPEED  ## ...and moving horizontally at least this fast (m/s).
const AIR_DRAG_KEEP_PER_FRAME := 1.0 - 1.0 / 32.0  ## Share of horizontal speed kept per classic frame (1/60 s).


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
