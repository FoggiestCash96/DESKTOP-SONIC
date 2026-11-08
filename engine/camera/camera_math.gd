class_name CameraMath
extends RefCounted
## Camera math, kept free of nodes so the unit tests can call it. Angles are in radians.


## Offset from the point a camera orbits to the camera itself, for this yaw, pitch and distance.
## Yaw 0 puts the camera on the +Z side looking toward -Z; negative pitch raises it to look down.
static func orbit_offset(yaw: float, pitch: float, distance: float) -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3(0.0, 0.0, distance)


## The yaw that points a camera along `forward` on the horizontal plane.
static func yaw_facing(forward: Vector3) -> float:
	return atan2(-forward.x, -forward.z)


## The horizontal forward direction of a camera with this yaw.
static func forward_for_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## `current` turned toward `target` by at most `max_step`, the short way round.
static func approach_angle(current: float, target: float, max_step: float) -> float:
	var difference := wrapf(target - current, -PI, PI)
	return current + clampf(difference, -max_step, max_step)


## Field of view (degrees) for a speed: `rest` when still, easing linearly to `fast` at `top`
## speed and above.
static func speed_fov(speed: float, top: float, rest: float, fast: float) -> float:
	if top <= 0.0:
		return rest
	return lerpf(rest, fast, clampf(speed / top, 0.0, 1.0))


## Strength (0 to 1) of a speed effect at `speed`: nothing below `start`, full from `full`, easing between.
static func effect_amount(speed: float, start: float, full: float) -> float:
	return smoothstep(start, full, speed)


## How far ahead of the player to aim: `seconds` of their velocity, but no more than `max_distance`.
static func look_ahead(velocity: Vector3, seconds: float, max_distance: float) -> Vector3:
	return (velocity * seconds).limit_length(max_distance)


## Weight for exponential smoothing that closes 63% of the gap every `time_constant` seconds,
## the same at any frame rate.
static func smoothing(time_constant: float, delta: float) -> float:
	if time_constant <= 0.0:
		return 1.0
	return 1.0 - exp(-delta / time_constant)


## Eased weight `elapsed` seconds into a blend that lasts `duration` seconds.
static func blend_weight(elapsed: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return smoothstep(0.0, 1.0, clampf(elapsed / duration, 0.0, 1.0))


## Whether `point` lies inside a box of `size` centered on and turned with `box`.
static func box_contains(box: Transform3D, size: Vector3, point: Vector3) -> bool:
	var local := box.affine_inverse() * point
	var half := size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## Which way the stick points, as an angle: 0 is straight up (forward), positive toward the right.
static func stick_angle(stick: Vector2) -> float:
	return atan2(stick.x, -stick.y)


## The yaw movement input is relative to while the stick stays held through a change of view. It
## starts at `old_yaw`, the yaw input was relative to before, and turns along with the stick
## (`stick_turn`: how far the stick has turned since, in radians, positive toward the right), up to
## the new view's `new_yaw`. So the player keeps going the same way while they bring their thumb
## round to suit the new view. Turning the stick the other way leaves it at `old_yaw`.
static func held_input_yaw(old_yaw: float, new_yaw: float, stick_turn: float) -> float:
	var change := wrapf(new_yaw - old_yaw, -PI, PI)
	if change * stick_turn <= 0.0:
		return old_yaw
	return old_yaw + signf(change) * minf(absf(stick_turn), absf(change))


## Whether input should keep to the old view (see held_input_yaw): only until the stick has come
## round as far as the view has, or has turned the other way by more than `max_other_way` (a new
## direction, for the new view). Views facing the same way have nothing to hold.
static func keeps_input_hold(old_yaw: float, new_yaw: float, stick_turn: float, max_other_way: float) -> bool:
	const CLOSE := 0.02  # Within about 1°, the stick has come round: a pad never lands exactly.
	var change := wrapf(new_yaw - old_yaw, -PI, PI)
	if absf(change) < CLOSE:
		return false
	if change * stick_turn > 0.0:
		return absf(stick_turn) < absf(change) - CLOSE
	return absf(stick_turn) <= max_other_way


## How far before the nearer end of a 2.5D section's box a point is (m), when it's in the section's
## lead-in: within `lead_in` of that end along the box's X axis, within the box's height, and within
## a funnel that widens `flare` m across for every metre further out. 0 when it isn't. `local` is
## the point in the box's own space and `half` is half the box's size.
static func lead_in_distance(local: Vector3, half: Vector3, lead_in: float, flare: float) -> float:
	var before := absf(local.x) - half.x
	if before <= 0.0 or before > lead_in or absf(local.y) > half.y:
		return 0.0
	if absf(local.z) > half.z + before * flare:
		return 0.0
	return before
