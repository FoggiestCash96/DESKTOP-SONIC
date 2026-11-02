extends "res://tests/test_suite.gd"
## Guards the art (docs/DESIGN.md, section 8.3): the art bank the project names has a model for
## every object the engine dresses and every material it asks for; a model only names nodes the
## object really has, so a renamed node can't leave a part floating loose; every badnik and the
## boss wear their models; and each act shows its art over a hidden greybox that still collides,
## with the art built from the greybox the act has now.

const ExportGreybox := preload("res://tools/godot/export_greybox.gd")
const ACTS := {
	"res://content/sonic/stages/emerald_shore/act_1.tscn": "res://content/sonic/stages/emerald_shore/art/act_1.greybox.json",
	"res://content/sonic/stages/emerald_shore/act_8.tscn": "res://content/sonic/stages/emerald_shore/art/act_8.greybox.json",
}
## The models the engine's objects ask the bank for (ArtBank.model), and the scenes they dress.
const MODELS := {
	&"spring": "res://engine/gimmicks/spring.tscn",
	&"dash_panel": "res://engine/gimmicks/dash_panel.tscn",
	&"item_monitor": "res://engine/collectibles/item_monitor.tscn",
	&"checkpoint": "res://engine/gimmicks/checkpoint.tscn",
	&"goal": "res://engine/gimmicks/goal.tscn",
	&"extra_life": "res://engine/collectibles/extra_life.tscn",
	&"spikes": "res://engine/gimmicks/spikes.tscn",
	&"animal": "res://engine/enemies/base/animal.tscn",
}
const MATERIALS: Array[StringName] = [&"spikes_plate", &"wave_water", &"wave_foam"]  ## ArtBank.material
const BADNIKS: Array[String] = [
	"res://content/sonic/enemies/scuttler.tscn",
	"res://content/sonic/enemies/galegull.tscn",
	"res://content/sonic/enemies/pearlshot.tscn",
	"res://content/sonic/enemies/leapfin.tscn",
]
const BOSS := "res://content/sonic/bosses/emerald_shore/crab_mech.tscn"


func test_the_project_names_an_art_bank() -> void:
	assert_true(ArtBank.find() is ArtBank, "the setting %s doesn't name an ArtBank" % ArtBank.SETTING)


func test_the_bank_has_every_model_and_material_the_engine_asks_for() -> void:
	for model_name: StringName in MODELS:
		assert_true(ArtBank.model(model_name) != null, "no model for '%s'" % model_name)
	for material_name in MATERIALS:
		assert_true(ArtBank.material(material_name) != null, "no material for '%s'" % material_name)


func test_a_skin_swaps_meshes_adds_parts_and_hides_what_it_names() -> void:
	var target := Node3D.new()
	var head := Node3D.new()
	head.name = "Head"
	target.add_child(head)
	var lamp := _mesh_node("Lamp", BoxMesh.new())
	lamp.material_override = StandardMaterial3D.new()
	head.add_child(lamp)
	var old := _mesh_node("Old", BoxMesh.new())
	target.add_child(old)
	var kept := _mesh_node("Kept", BoxMesh.new())
	target.add_child(kept)

	var model := Node3D.new()
	var new_lamp := SphereMesh.new()
	_add_owned(model, _mesh_node("Head__Lamp", new_lamp))
	var bolt := CylinderMesh.new()
	_add_owned(model, _mesh_node("Head__Bolt", bolt))
	var hide := Node3D.new()
	hide.name = "Old"
	_add_owned(model, hide)
	var packed := PackedScene.new()
	packed.pack(model)
	model.free()

	ModelSkin.apply(target, packed)
	assert_eq(lamp.mesh, new_lamp, "the lamp didn't get the model's mesh")
	assert_true(lamp.material_override == null, "the lamp kept its placeholder's material")
	assert_true(head.has_node("Bolt") and (head.get_node("Bolt") as MeshInstance3D).mesh == bolt, "the bolt wasn't added under the head")
	assert_true(not old.visible, "the placeholder the model names with an empty is still showing")
	assert_true(kept.visible and kept.mesh is BoxMesh, "a placeholder the model doesn't name changed")
	target.free()


func test_every_object_model_fits_its_object() -> void:
	for model_name: StringName in MODELS:
		var scene: String = MODELS[model_name]
		_assert_fits(ArtBank.model(model_name), scene, "")


func test_every_badnik_wears_a_model_that_fits() -> void:
	for scene in BADNIKS:
		var skin := _property(scene, ".", &"skin") as PackedScene
		assert_true(skin != null, "%s has no skin" % scene.get_file())
		_assert_fits(skin, scene, "")


func test_the_boss_and_its_ship_wear_models_that_fit() -> void:
	var skin := _property(BOSS, "CrabMech", &"skin") as PackedScene
	var ship_skin := _property(BOSS, "CrabMech", &"ship_skin") as PackedScene
	assert_true(skin != null, "the crab mech has no skin")
	assert_true(ship_skin != null, "the ship has no skin")
	_assert_fits(skin, BOSS, "CrabMech")
	_assert_fits(ship_skin, BOSS, "EggShip")


func test_each_act_shows_its_art_over_a_hidden_greybox_that_still_collides() -> void:
	for act: String in ACTS:
		var state := (load(act) as PackedScene).get_state()
		var art := false
		var solid := 0
		for node in state.get_node_count():
			var path := String(state.get_node_path(node)).trim_prefix("./")
			if path == "Art":
				var instance := state.get_node_instance(node)
				art = instance != null and instance.resource_path.ends_with(".glb")
			if not ClassDB.is_parent_class(state.get_node_type(node), &"CSGShape3D"):
				continue
			assert_eq(_value(state, node, &"visible"), false, "%s: %s shows the greybox" % [act.get_file(), path])
			if _value(state, node, &"use_collision") == true:
				solid += 1  # Some greybox pieces are only scenery, like Act 8's towers out at sea.
		assert_true(art, "%s has no Art from a .glb" % act.get_file())
		assert_true(solid > 0, "%s has no solid greybox left" % act.get_file())


func test_each_act_has_a_toon_sea_and_sky() -> void:
	for act: String in ACTS:
		var sea := _property(act, "Sea", &"material_override") as ShaderMaterial
		assert_true(sea != null and sea.shader.resource_path.ends_with("toon_water.gdshader"), "%s: the sea isn't toon water" % act.get_file())
		var environment := _property(act, "WorldEnvironment", &"environment") as Environment
		var sky := environment.sky.sky_material as ShaderMaterial if environment and environment.sky else null
		assert_true(sky != null and sky.shader.resource_path.ends_with("toon_sky.gdshader"), "%s: the sky isn't a toon sky" % act.get_file())


func test_each_acts_art_is_built_from_its_greybox_as_it_is_now() -> void:
	for act: String in ACTS:
		var stage := (load(act) as PackedScene).instantiate()
		var now := JSON.parse_string(JSON.stringify(ExportGreybox.export_stage(stage, act))) as Dictionary
		stage.free()
		var greybox: String = ACTS[act]
		var built := JSON.parse_string(FileAccess.get_file_as_string(greybox)) as Dictionary
		for key: String in built:
			assert_true(_comparable(now.get(key)) == _comparable(built[key]),
					"%s: its %s changed since its art was built: export its greybox and build its art again (%s)" % [act.get_file(), key, greybox.get_file()])


func test_the_fortress_act_has_a_storm() -> void:
	var act := "res://content/sonic/stages/emerald_shore/act_8.tscn"
	var state := (load(act) as PackedScene).get_state()
	var storm := false
	for node in state.get_node_count():
		if String(state.get_node_path(node)).trim_prefix("./") == "Storm":
			storm = _value(state, node, &"light") != null
	assert_true(storm, "act_8 has no Storm lighting up its sun")


func test_a_loop_has_uvs_for_its_material() -> void:
	var loop := LoopTrack.new()
	loop._build()
	var mesh := (loop.get_node("Mesh") as MeshInstance3D).mesh as ArrayMesh
	var format := mesh.surface_get_format(0)
	assert_true(format & Mesh.ARRAY_FORMAT_TEX_UV != 0, "the loop's mesh has no UVs")
	assert_true(format & Mesh.ARRAY_FORMAT_COLOR != 0, "the loop's mesh has no colours for its underside")
	loop.free()


## A section of a greybox's JSON without the signs' text sizes. Those come from fonts, and a
## character a font lacks (like the signs' arrows) is drawn from whatever font the computer has, so
## they differ from one machine to another while the greybox stays the same.
func _comparable(section: Variant) -> Variant:
	if not section is Array:
		return section
	var result := []
	for item: Variant in section:
		if item is Dictionary and (item as Dictionary).has("text_size"):
			var copy := (item as Dictionary).duplicate()
			copy.erase("text_size")
			result.append(copy)
		else:
			result.append(item)
	return result


## Every part of `model` names a node of `scene` (under `root`), or a node a new part can go under.
func _assert_fits(model: PackedScene, scene: String, root: String) -> void:
	if model == null:
		return
	var paths := {}
	var state := (load(scene) as PackedScene).get_state()
	for node in state.get_node_count():
		var path := String(state.get_node_path(node)).trim_prefix("./")
		if root != "":
			if path != root and not path.begins_with(root + "/"):
				continue
			path = path.trim_prefix(root).trim_prefix("/")
		paths[path] = true
	var instance := model.instantiate()
	for part in instance.find_children("*", "Node3D", true, false):
		var path := String(part.name).replace(ModelSkin.SEPARATOR, "/")
		var parent := path.get_base_dir()
		assert_true(paths.has(path) or paths.has(parent) or parent == "", "%s: %s has no node %s" % [scene.get_file(), model.resource_path.get_file(), path])
	instance.free()


func _mesh_node(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	return node


func _add_owned(root: Node, node: Node) -> void:
	root.add_child(node)
	node.owner = root


func _value(state: SceneState, node: int, property: StringName) -> Variant:
	for i in state.get_node_property_count(node):
		if state.get_node_property_name(node, i) == property:
			return state.get_node_property_value(node, i)
	return null


func _property(scene: String, node_path: NodePath, property: StringName) -> Variant:
	var state := (load(scene) as PackedScene).get_state()
	for node in state.get_node_count():
		var path := String(state.get_node_path(node)).trim_prefix("./")
		if path == String(node_path):
			return _value(state, node, property)
	return null
