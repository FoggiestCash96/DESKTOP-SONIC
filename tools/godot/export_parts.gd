extends SceneTree
## Writes the layout of a scene's shapes as JSON, for Blender scripts that model parts to dress
## them (see engine/art/model_skin.gd). Run it from the repository root:
##
##     godot --headless --path . --script res://tools/godot/export_parts.gd -- <scene.tscn> <out.json>
##
## For every 3D node it records its path, its transform relative to the scene's root, and for a
## mesh, the placeholder's shape and colour, so a model can match its proportions. The scene isn't
## added to the tree, so none of its scripts run.

const PRECISION := 0.0001


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := (load(args[0]) as PackedScene).instantiate()
	var nodes: Array[Dictionary] = []
	for node in scene.find_children("*", "Node3D", true, false):
		var entry := {
			"path": String(scene.get_path_to(node)),
			"type": node.get_class(),
			"transform": _transform(_relative_transform(node as Node3D, scene)),
		}
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			entry.mesh = _mesh(mesh_instance.mesh)
			var material := mesh_instance.material_override as BaseMaterial3D
			if material == null and mesh_instance.mesh:
				material = mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
			if material:
				var colour := material.albedo_color
				entry.colour = [_number(colour.r), _number(colour.g), _number(colour.b)]
		elif node is MultiMeshInstance3D:
			var multimesh := (node as MultiMeshInstance3D).multimesh
			entry.mesh = _mesh(multimesh.mesh if multimesh else null)
		nodes.append(entry)
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify({"scene": args[0], "nodes": nodes}, "\t", false) + "\n")
	file.close()
	print("wrote %s: %d nodes" % [args[1], nodes.size()])
	scene.free()
	quit()


static func _relative_transform(node: Node3D, scene_root: Node) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent and parent != scene_root:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


static func _mesh(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}
	var info := {"class": mesh.get_class()}
	for property: String in ["size", "radius", "height", "top_radius", "bottom_radius", "inner_radius", "outer_radius"]:
		var value: Variant = mesh.get(property)
		if value is float:
			info[property] = _number(value as float)
		elif value is Vector3:
			var vector := value as Vector3
			info[property] = [_number(vector.x), _number(vector.y), _number(vector.z)]
		elif value is Vector2:
			var flat := value as Vector2
			info[property] = [_number(flat.x), _number(flat.y)]
	var box := mesh.get_aabb()
	info.aabb = [_number(box.position.x), _number(box.position.y), _number(box.position.z), _number(box.size.x), _number(box.size.y), _number(box.size.z)]
	return info


static func _transform(transform: Transform3D) -> Dictionary:
	return {
		"x": [_number(transform.basis.x.x), _number(transform.basis.x.y), _number(transform.basis.x.z)],
		"y": [_number(transform.basis.y.x), _number(transform.basis.y.y), _number(transform.basis.y.z)],
		"z": [_number(transform.basis.z.x), _number(transform.basis.z.y), _number(transform.basis.z.z)],
		"origin": [_number(transform.origin.x), _number(transform.origin.y), _number(transform.origin.z)],
	}


static func _number(value: float) -> float:
	return snappedf(value, PRECISION)
