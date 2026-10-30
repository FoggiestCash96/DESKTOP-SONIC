class_name GimmickMath
extends RefCounted
## Math for springs and bouncing objects, kept free of nodes so the unit tests can call it.

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
