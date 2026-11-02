class_name Storm
extends Node3D
## Bad weather: rain falling around the camera, and lightning now and then that lights up the sky
## (the `flash` parameter of a sky made with engine/art/toon_sky.gdshader) and the stage's sun.
## Put one in a stage; it pauses with the game.

@export var light: DirectionalLight3D  ## Brightens with each flash.
@export var sky_material: ShaderMaterial  ## Leave empty to use the stage's environment's sky.
@export var interval := Vector2(6.0, 14.0)  ## Seconds between strikes, chosen at random in this range.
@export var flash_strength: float = 1.6  ## How much brighter the light gets at the peak of a flash.
@export var rain: bool = true
@export var rain_amount: int = 2400
@export var rain_area: float = 40.0  ## Width of the square of rain around the camera (m).
@export var rain_speed: float = 30.0  ## (m/s)
@export var wind := Vector3(4.0, 0.0, 0.0)  ## Blows the rain sideways (m/s).

var _rain: GPUParticles3D
var _countdown: float = 0.0
var _light_energy: float = 1.0
var _flash: Tween


func _ready() -> void:
	if sky_material == null:
		var environment := get_viewport().find_world_3d().environment
		if environment and environment.sky:
			sky_material = environment.sky.sky_material as ShaderMaterial
	if light:
		_light_energy = light.light_energy
	if rain:
		_rain = _make_rain()
		add_child(_rain)
	_countdown = randf_range(interval.x, interval.y)


func _exit_tree() -> void:
	set_flash(0.0)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if _rain and camera:
		_rain.global_position = camera.global_position + Vector3.UP * 14.0
	_countdown -= delta
	if _countdown <= 0.0:
		_countdown = randf_range(interval.x, interval.y)
		strike()


## A flash of lightning: two quick flickers, then it fades.
func strike() -> void:
	if _flash:
		_flash.kill()
	_flash = create_tween()
	_flash.tween_method(set_flash, 0.0, 1.0, 0.05)
	_flash.tween_method(set_flash, 1.0, 0.25, 0.08)
	_flash.tween_method(set_flash, 0.25, 0.85, 0.05)
	_flash.tween_method(set_flash, 0.85, 0.0, 0.5)


func set_flash(amount: float) -> void:
	if sky_material:
		sky_material.set_shader_parameter("flash", amount)
	if light:
		light.light_energy = _light_energy * (1.0 + amount * flash_strength)


func _make_rain() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Rain"
	particles.amount = rain_amount
	particles.lifetime = 1.0
	particles.preprocess = 1.0
	particles.local_coords = false
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	particles.visibility_aabb = AABB(Vector3(-rain_area, -40.0, -rain_area), Vector3(rain_area * 2.0, 60.0, rain_area * 2.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(rain_area * 0.5, 2.0, rain_area * 0.5)
	motion.direction = (Vector3.DOWN * rain_speed + wind).normalized()
	motion.spread = 2.0
	motion.initial_velocity_min = rain_speed * 0.9
	motion.initial_velocity_max = rain_speed * 1.1
	motion.gravity = Vector3.ZERO
	particles.process_material = motion
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.7)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.78, 0.83, 0.92, 0.25)
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = look
	particles.draw_pass_1 = drop
	return particles
