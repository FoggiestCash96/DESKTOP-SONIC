@tool
extends EditorScenePostImport
## Import script for character models: set it as the import script of a character's .glb (the
## Import dock's "Import Script" field, or import_script/path in the .glb.import file). It gives
## every material the toon look and makes the cyclic animations loop, so a model exported from
## Blender with the standard animation names (see CharacterModel) is ready to animate.

const TOON_ROUGHNESS := 0.6  ## Rough enough for a soft highlight band rather than a shiny spot.


func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		_make_toon((node as MeshInstance3D).mesh)
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var animations := node as AnimationPlayer
		for library_name in animations.get_animation_library_list():
			var library := animations.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				if animation_name in CharacterModel.LOOPED:
					library.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	return scene


## Cel shading: lighting falls into a lit and a shaded band instead of a smooth gradient.
func _make_toon(mesh: Mesh) -> void:
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as BaseMaterial3D
		if material:
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			material.specular_mode = BaseMaterial3D.SPECULAR_TOON
			material.metallic = 0.0
			material.roughness = TOON_ROUGHNESS
