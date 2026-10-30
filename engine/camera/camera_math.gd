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
