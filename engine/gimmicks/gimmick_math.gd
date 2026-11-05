class_name GimmickMath
extends RefCounted
## Math for springs, bouncing objects, tidal waves, tides, moving platforms and breakable walls,
## kept free of nodes so the unit tests can call it.

const ALONG_GROUND := 0.5  ## A launch direction this close to the surface (cosine from its normal, about 60°) runs along the ground.


## A spring's launch velocity: `speed` along `direction` (a unit vector). With `keep_momentum` the
## player keeps the part of their velocity across that direction, as classic upward springs keep
## running speed. Without it they leave exactly along the spring.
static func spring_velocity(velocity: Vector3, direction: Vector3, speed: float, keep_momentum: bool) -> Vector3:
	var across := velocity - direction * direction.dot(velocity) if keep_momentum else Vector3.ZERO
	return across + direction * speed


## Whether a launch direction runs along a surface with this normal rather than away from it, as
## for a spring lying on its side. Such springs push a grounded player along the ground.
static func runs_along(direction: Vector3, normal: Vector3) -> bool:
	return absf(direction.dot(normal)) < ALONG_GROUND


## `velocity` after bouncing off a surface with this normal: the part into the surface reverses,
## keeping `restitution` of its size, and the part along the surface carries on.
static func bounce(velocity: Vector3, normal: Vector3, restitution: float) -> Vector3:
	var into := velocity.dot(normal)
	if into >= 0.0:
		return velocity
	return velocity - normal * into * (1.0 + restitution)


## Where a tidal wave is `time` seconds into its cycle of a surge, a backwash and a rest: x is how
## far along its run the water is (0 at the shore, 1 at the top of its reach), and y which way it
## is moving (1 surging up, -1 draining back, 0 resting).
static func wave_cycle(time: float, surge_time: float, backwash_time: float, rest_time: float) -> Vector2:
	var t := fposmod(time, surge_time + backwash_time + rest_time)
	if t < surge_time:
		return Vector2(t / surge_time, 1.0)
	t -= surge_time
	if t < backwash_time:
		return Vector2(1.0 - t / backwash_time, -1.0)
	return Vector2.ZERO


## How high a tide is `time` seconds into its cycle, from 0 (low) to 1 (high): it stays low for
## `low_time`, rises over `rise_time`, stays high for `high_time` and falls over `fall_time`, easing
## in and out of each change.
static func tide_level(time: float, low_time: float, rise_time: float, high_time: float, fall_time: float) -> float:
	var t := fposmod(time, low_time + rise_time + high_time + fall_time)
	if t < low_time:
		return 0.0
	t -= low_time
	if t < rise_time:
		return smoothstep(0.0, 1.0, t / rise_time)
	t -= rise_time
	if t < high_time:
		return 1.0
	t -= high_time
	return 1.0 - smoothstep(0.0, 1.0, t / fall_time)


## How far along its run a moving platform is `time` seconds into its cycle, from 0 (at its start)
## to 1 (at the far end): it travels out over `travel_time`, easing in and out, waits `pause_time`,
## travels back and waits again.
static func platform_travel(time: float, travel_time: float, pause_time: float) -> float:
	var t := fposmod(time, 2.0 * (travel_time + pause_time))
	if t < travel_time:
		return smoothstep(0.0, 1.0, t / travel_time)
	t -= travel_time
	if t < pause_time:
		return 1.0
	t -= pause_time
	if t < travel_time:
		return 1.0 - smoothstep(0.0, 1.0, t / travel_time)
	return 0.0


## Whether something moving at `velocity` smashes a breakable wall that lies in `direction` (a unit
## vector toward it): it has to be closing on the wall at `speed` or faster.
static func breaks_wall(velocity: Vector3, direction: Vector3, speed: float) -> bool:
	return velocity.dot(direction) >= speed
