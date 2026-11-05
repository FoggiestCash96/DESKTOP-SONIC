class_name PlatformLook
extends RefCounted
## Builds what a platform looks like from its size, for MovingPlatform and CrumblingPlatform: a slab,
## or a raft of logs lying along X. The top is at y = 0. Materials come from the art bank
## ("platform_stone", "crumbling_rock", "log_bark", "breakable_rock"), with plain colours as fallbacks.

const FALLBACK_COLOURS := {
	&"platform_stone": Color(0.62, 0.58, 0.52),
	&"crumbling_rock": Color(0.8, 0.55, 0.35),
	&"breakable_rock": Color(0.7, 0.5, 0.32),
	&"log_bark": Color(0.55, 0.36, 0.2),
}


## A node holding the platform's meshes: logs if `logs`, else a slab with the art bank's `slab_material`.
static func build(logs: bool, size: Vector3, slab_material: StringName = &"platform_stone") -> Node3D:
	var root := Node3D.new()
	root.name = "Look"
	if logs:
		var count := maxi(1, roundi(size.z / maxf(size.y, 0.3)))
		var radius := size.z / float(count) * 0.5
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = radius
		log_mesh.bottom_radius = radius
		log_mesh.height = size.x
		log_mesh.radial_segments = 10
		log_mesh.rings = 1
		var bark := material(&"log_bark")
		for i in count:
			var piece := MeshInstance3D.new()
			piece.mesh = log_mesh
			piece.material_override = bark
			piece.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, -radius, -size.z * 0.5 + radius * (2.0 * float(i) + 1.0)))
			root.add_child(piece)
	else:
		var slab := BoxMesh.new()
		slab.size = size
		var piece := MeshInstance3D.new()
		piece.mesh = slab
		piece.material_override = material(slab_material)
		piece.position = Vector3(0.0, -size.y * 0.5, 0.0)
		root.add_child(piece)
	return root


## The art bank's material `material_name`, or a plain toon colour standing in for it.
static func material(material_name: StringName) -> Material:
	var found := ArtBank.material(material_name)
	if found:
		return found
	var plain := StandardMaterial3D.new()
	plain.albedo_color = FALLBACK_COLOURS.get(material_name, Color(0.6, 0.6, 0.6))
	plain.roughness = 0.9
	plain.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	plain.specular_mode = BaseMaterial3D.SPECULAR_TOON
	return plain
