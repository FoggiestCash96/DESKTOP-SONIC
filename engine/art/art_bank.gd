class_name ArtBank
extends Resource
## The art the engine's own objects use, by name: models that replace an object's placeholder
## shapes (see ModelSkin), and materials for meshes the engine builds itself, such as waves and
## the plates of spike beds. The project setting game/art/art_bank names the bank the game uses.
## Without one, or without a name in it, an object keeps its placeholder look.

const SETTING := "game/art/art_bank"

@export var models: Dictionary[StringName, PackedScene] = {}
@export var materials: Dictionary[StringName, Material] = {}


static func find() -> Resource:  # plain Resource: a self-referencing static func leaks at exit
	var path: String = ProjectSettings.get_setting(SETTING, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)


## The model named `model_name` in the game's bank, or null.
static func model(model_name: StringName) -> PackedScene:
	var bank := find()
	if bank == null:
		return null
	return (bank.get("models") as Dictionary).get(model_name) as PackedScene


## The material named `material_name` in the game's bank, or `fallback`.
static func material(material_name: StringName, fallback: Material = null) -> Material:
	var bank := find()
	if bank == null:
		return fallback
	return (bank.get("materials") as Dictionary).get(material_name, fallback) as Material
