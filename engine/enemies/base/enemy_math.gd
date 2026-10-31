class_name EnemyMath
extends RefCounted
## Math for enemies and bosses, kept free of nodes so the unit tests can call it.


## Height above its spot of a leaper `u` of the way through a leap `height` high (u from 0 to 1):
## a parabola up from the spot and back down to it.
static func leap_height(u: float, height: float) -> float:
	return 4.0 * height * u * (1.0 - u)


## How far a leaper's nose points up (radians) `u` of the way through a leap `height` high and
## `distance` long: straight up at the start of a leap on the spot, level at the top.
static func leap_pitch(u: float, height: float, distance: float) -> float:
	return atan2(4.0 * height * (1.0 - 2.0 * u), absf(distance))


## Which phase a boss is in with `hits_left`: how many of `phase_changes` (the hits left at which
## its phase changes, such as [4, 2]) it has reached. 0 is the first phase.
static func boss_phase(hits_left: int, phase_changes: Array[int]) -> int:
	var phase := 0
	for change in phase_changes:
		if hits_left <= change:
			phase += 1
	return phase
