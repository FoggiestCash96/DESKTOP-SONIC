class_name ModelSkin
extends RefCounted
## Swaps an object's placeholder shapes for a model's, keeping the object's own nodes, so its
## scripts, collision and animations work as before.
##
## The model is a scene, usually an imported .glb, whose parts are named after the nodes they
## dress, with "__" standing for "/":
## - A mesh named "Head__Lamp" becomes the mesh of the object's Head/Lamp (and clears that node's
##   material override, so the model's own materials show; scripts that colour a part at run time
##   do so after the swap). If the object has no such node, the mesh is added under the deepest
##   node the name leads to, so "Base__Bolts" adds a Bolts mesh under Base.
## - A mesh named after a MultiMeshInstance3D becomes the mesh it repeats.
## - An empty (a node with no mesh) named after a placeholder hides it.
## Parts are modelled in the space of the node they dress: their own transforms are ignored.

const SEPARATOR := "__"


## Dresses `target` in `model`. Does nothing without a model, or in the editor, where the swap
## would be saved into the scene.
static func apply(target: Node, model: PackedScene) -> void:
	if model == null or target == null or Engine.is_editor_hint():
		return
	var skin := model.instantiate()
	for part in skin.find_children("*", "", true, false):
		var path := String(part.name).replace(SEPARATOR, "/")
		var node := target.get_node_or_null(NodePath(path))
		if part is MeshInstance3D:
			var mesh := (part as MeshInstance3D).mesh
			if node is MeshInstance3D:
				(node as MeshInstance3D).mesh = mesh
				(node as MeshInstance3D).material_override = null
			elif node is MultiMeshInstance3D:
				(node as MultiMeshInstance3D).multimesh.mesh = mesh
			elif node == null:
				_add(target, String(part.name).split(SEPARATOR), mesh)
		elif part is Node3D and node is MeshInstance3D:
			(node as MeshInstance3D).visible = false
	skin.free()


static func _add(target: Node, names: PackedStringArray, mesh: Mesh) -> void:
	var parent := target
	for index in names.size() - 1:
		var next := parent.get_node_or_null(NodePath(names[index]))
		if next == null:
			break
		parent = next
	var added := MeshInstance3D.new()
	added.name = names[names.size() - 1]
	added.mesh = mesh
	parent.add_child(added)
