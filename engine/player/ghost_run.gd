class_name GhostRun
extends RefCounted
## A run recorded in time attack, to race as a ghost: where the player's model was, how it was turned
## and the pose it showed (CharacterModel.POSES, with the speed it showed it at), at most every
## INTERVAL seconds of the stage clock. PlayerGhost plays one back, and SaveGame keeps the fastest
## run of each act.

const VERSION := 1
const INTERVAL := 1.0 / 30.0  ## Least stage-clock time between samples (s).

var times: PackedFloat32Array = []  ## The stage clock at each sample, rising.
var points: PackedVector3Array = []  ## Where the model was.
var turns: PackedFloat32Array = []  ## How it was turned: a quaternion (x, y, z, w) per sample.
var poses: PackedByteArray = []  ## Its pose, as an index into CharacterModel.POSES.
var speeds: PackedFloat32Array = []  ## The speed its pose showed.


## Adds a sample at stage clock `time`: the model at `at`, showing `pose` at `speed`. Skipped if it
## comes less than INTERVAL after the last one, unless `always` (as at the goal); never added out of
## order.
func add(time: float, at: Transform3D, pose: StringName, speed: float, always := false) -> void:
	if not times.is_empty():
		var last := times[times.size() - 1]
		# The tolerance keeps float error from pushing a sample a tick late.
		if time <= last or (time < last + INTERVAL * 0.999 and not always):
			return
	times.append(time)
	points.append(at.origin)
	var turn := at.basis.get_rotation_quaternion()
	turns.append_array([turn.x, turn.y, turn.z, turn.w])
	poses.append(maxi(CharacterModel.POSES.find(pose), 0))
	speeds.append(speed)


func is_empty() -> bool:
	return times.is_empty()


## Seconds of stage clock the run lasts.
func duration() -> float:
	return times[times.size() - 1] if not times.is_empty() else 0.0


## The model at stage clock `time`, between the samples either side: {transform, pose, speed}. Before
## the first sample it is at the first, after the last at the last. Empty with no samples.
func sample(time: float) -> Dictionary:
	if times.is_empty():
		return {}
	if times.size() == 1:
		return {"transform": Transform3D(Basis(_turn(0)), points[0]), "pose": CharacterModel.POSES[poses[0]], "speed": speeds[0]}
	var i := clampi(times.bsearch(time), 1, times.size() - 1)
	var span := times[i] - times[i - 1]
	var weight := clampf((time - times[i - 1]) / span, 0.0, 1.0) if span > 0.0 else 1.0
	return {
		"transform": Transform3D(Basis(_turn(i - 1).slerp(_turn(i), weight)), points[i - 1].lerp(points[i], weight)),
		"pose": CharacterModel.POSES[poses[i if weight >= 0.5 else i - 1]],
		"speed": lerpf(speeds[i - 1], speeds[i], weight),
	}


## The run as plain data, for SaveGame.save_ghost().
func to_dict() -> Dictionary:
	return {"version": VERSION, "times": times, "points": points, "turns": turns, "poses": poses, "speeds": speeds}


## Fills the run from to_dict()'s data. Returns false, leaving it as it was, if the data isn't a run
## this game can play, as from a damaged file.
func from_dict(data: Dictionary) -> bool:
	var version: Variant = data.get("version")
	var new_times: Variant = data.get("times")
	var new_points: Variant = data.get("points")
	var new_turns: Variant = data.get("turns")
	var new_poses: Variant = data.get("poses")
	var new_speeds: Variant = data.get("speeds")
	if not (version is int and version == VERSION and new_times is PackedFloat32Array and new_points is PackedVector3Array
			and new_turns is PackedFloat32Array and new_poses is PackedByteArray and new_speeds is PackedFloat32Array):
		return false
	var count := (new_times as PackedFloat32Array).size()
	if count == 0 or (new_points as PackedVector3Array).size() != count or (new_turns as PackedFloat32Array).size() != count * 4 \
			or (new_poses as PackedByteArray).size() != count or (new_speeds as PackedFloat32Array).size() != count:
		return false
	for i in count:
		if (new_poses as PackedByteArray)[i] >= CharacterModel.POSES.size() or (i > 0 and (new_times as PackedFloat32Array)[i] <= (new_times as PackedFloat32Array)[i - 1]):
			return false
	times = new_times
	points = new_points
	turns = new_turns
	poses = new_poses
	speeds = new_speeds
	return true


# Sample `index`'s turn, normalised again after its trip through 32-bit floats.
func _turn(index: int) -> Quaternion:
	return Quaternion(turns[index * 4], turns[index * 4 + 1], turns[index * 4 + 2], turns[index * 4 + 3]).normalized()
