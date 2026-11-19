class_name PlayerGhost
extends Node3D
## A see-through copy of a player's model replaying a GhostRun in step with the stage clock: the run
## to race in time attack. It stays a moment at the end of the run, then goes.

const COLOR := Color(0.55, 0.85, 1.0, 0.45)
const LINGER := 1.0  ## Seconds it stays at the end of its run.

var run: GhostRun
var _model: CharacterModel


## Plays `ghost_run` with a copy of `model_scene` (a CharacterModel). Call it before adding the ghost
## to the tree.
func setup(ghost_run: GhostRun, model_scene: PackedScene) -> void:
	run = ghost_run
	_model = model_scene.instantiate() as CharacterModel
	add_child(_model)
	var look := StandardMaterial3D.new()
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS  # Only its nearest surfaces show, not its insides.
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.albedo_color = COLOR
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = look
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	# It moves in _process, where interpolating between physics ticks would only drag it behind.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var frame := run.sample(GameState.time) if run and _model else {}
	visible = not frame.is_empty() and GameState.time <= run.duration() + LINGER
	if not visible:
		return
	global_transform = frame["transform"] as Transform3D
	_model.animate(frame["pose"] as StringName, float(frame["speed"]))
