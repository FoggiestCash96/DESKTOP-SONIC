class_name CharacterModel
extends Node3D
## A character's model and animations, driven by the player wearing it. The model faces -Z with
## its feet at the origin. Its AnimationTree (%AnimationTree) mixes the standard animations: on
## the ground a speed blend of idle, walk, jog, run and max_run, and otherwise one of the other
## poses, picked by PlayerMotion.pose(). A model needs animations with exactly these names.

const POSES: Array[StringName] = [&"ground", &"ball", &"spring", &"fall", &"skid", &"push", &"hurt", &"death", &"victory"]
const RUN_CYCLE: Array[StringName] = [&"idle", &"walk", &"jog", &"run", &"max_run"]  ## Blended by speed on the ground.
const RUN_CYCLE_SPEEDS: Array[float] = [0.0, 2.0, 5.0, 10.0, 18.0]  ## Ground speed (m/s) at which each plays on its own.
const LOOPED: Array[StringName] = [&"idle", &"walk", &"jog", &"run", &"max_run", &"skid", &"ball", &"fall", &"push", &"victory"]
const BALL_SPIN_SPEED := 6.0  ## Speed (m/s) at which the ball animation plays at its own rate; faster spins faster.

var _pose: StringName = &""

@onready var _tree: AnimationTree = %AnimationTree


## Shows `pose` (one of POSES) at `speed` (m/s): ground speed for the run cycle, or how fast the
## ball is moving for its spin.
func animate(pose: StringName, speed: float) -> void:
	if pose != _pose:
		_pose = pose
		_tree.set("parameters/state/transition_request", String(pose))
	_tree.set("parameters/run_cycle/blend_position", speed)
	_tree.set("parameters/run_cycle_speed/scale", run_cycle_rate(speed))
	_tree.set("parameters/ball_speed/scale", clampf(absf(speed) / BALL_SPIN_SPEED, 0.75, 3.0))


## Playback rate of the run cycle: normal up to the max run's speed, quicker beyond it.
static func run_cycle_rate(speed: float) -> float:
	var top_blend := RUN_CYCLE_SPEEDS[RUN_CYCLE_SPEEDS.size() - 1]
	return 1.0 + maxf(speed - top_blend, 0.0) / top_blend
