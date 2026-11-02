@tool
extends EditorScenePostImport
## Import script for art made in Blender: stages, props and object models. Set it as a .glb's
## import script (the Import dock's "Import Script" field, or import_script/path in the .glb.import
## file).
##
## Materials are matched by name to a material library, so the look can be tuned in Godot without
## exporting again: a material named "grass" becomes materials/grass.tres next to the .glb if there
## is one, or else grass.tres in the folder the project setting game/art/material_library names.
## Every other material gets the toon look and shows the model's vertex colours, if it has any.
## A mesh whose name ends in "_noshadow" casts no shadow (distant scenery, water, small detail).

const LIBRARY_SETTING := "game/art/material_library"
const NO_SHADOW_SUFFIX := "_noshadow"
const TOON_ROUGHNESS := 0.6  ## Rough enough for a soft highlight band rather than a shiny spot.


func _post_import(scene: Node) -> Object:
	var folders := PackedStringArray([get_source_file().get_base_dir().path_join("materials")])
	var library: String = ProjectSettings.get_setting(LIBRARY_SETTING, "")
	if library != "":
		folders.append(library)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if String(mesh_instance.name).ends_with(NO_SHADOW_SUFFIX):
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material == null:
				continue
			var replacement := find_in_library(material.resource_name, folders)
			if replacement:
				mesh.surface_set_material(surface, replacement)
			elif material is BaseMaterial3D:
				var array_mesh := mesh as ArrayMesh
				var has_colours := array_mesh != null and (array_mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0
				make_toon(material as BaseMaterial3D, has_colours)
	return scene


## The first `<folder>/<material_name>.tres` that exists, or null.
static func find_in_library(material_name: String, folders: PackedStringArray) -> Material:
	if material_name == "":
		return null
	for folder in folders:
		var path := folder.path_join(material_name + ".tres")
		if ResourceLoader.exists(path):
			return load(path) as Material
	return null


## Cel shading: lighting falls into a lit and a shaded band instead of a smooth gradient.
static func make_toon(material: BaseMaterial3D, use_vertex_colours: bool) -> void:
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.metallic = 0.0
	material.roughness = TOON_ROUGHNESS
	if use_vertex_colours:
		material.vertex_color_use_as_albedo = true
