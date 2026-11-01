extends SceneTree
## Writes a stage's greybox as JSON, for the Blender scripts that build its art
## (tools/blender/stage_kit.py). Run it from the repository root:
##
##     godot --headless --path . --script res://tools/godot/export_greybox.gd -- <stage.tscn> <out.json>
##
## It records every CSG shape that is the root of its own CSG tree (polygons in depth mode, and
## boxes; anything else is baked into triangles), the loops, the camera volumes (so scenery can keep
## out of a side view's line of sight), invisible walls (boxes on static bodies in the Geometry
## group, so the art can show what stops the player), where the gimmicks and enemies are,
## the sea's height and the player's start. Positions are world
## positions in Godot's axes (Y up), rounded to 0.1 mm so the file only changes when the greybox does.
## The stage isn't added to the scene tree, so none of its scripts run.

const PRECISION := 0.0001


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage: godot --headless --path . --script res://tools/godot/export_greybox.gd -- <stage.tscn> <out.json>")
		quit(1)
		return
	var stage := (load(args[0]) as PackedScene).instantiate()
	var data := export_stage(stage, args[0])
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	file.close()
	print("wrote %s: %d pieces, %d loops, %d camera volumes, %d markers" % [args[1], (data.pieces as Array).size(),
			(data.loops as Array).size(), (data.camera_volumes as Array).size(), (data.markers as Array).size()])
	stage.free()
	quit()


static func export_stage(stage: Node, path: String) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var loops: Array[Dictionary] = []
	var camera_volumes: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	var markers: Array[Dictionary] = []
	var sea_height: Variant = null
	var player_start: Variant = null
	for node in stage.find_children("*", "", true, false):
		var parent := node.get_parent()
		if node is CSGShape3D and (node as CSGShape3D).is_root_shape():
			pieces.append(_piece(node as CSGShape3D, stage))
		elif node is LoopTrack:
			var loop := node as LoopTrack
			loops.append({
				"name": String(loop.name),
				"transform": _transform(world_transform(loop)),
				"radius": _number(loop.radius),
				"width": _number(loop.width),
				"exit_offset": _number(loop.exit_offset),
				"curb_height": _number(loop.curb_height),
			})
		elif node is StaticBody3D and parent and parent.name == &"Geometry":
			# An invisible wall: the art can show what stops the player there.
			for shape_node in node.find_children("*", "CollisionShape3D", false, false):
				var box := (shape_node as CollisionShape3D).shape as BoxShape3D
				if box:
					walls.append({
						"name": String(node.name),
						"transform": _transform(world_transform(shape_node as Node3D)),
						"size": _vector(box.size),
					})
		elif node is CameraVolume:
			var volume := node as CameraVolume
			camera_volumes.append({
				"name": String(volume.name),
				"transform": _transform(world_transform(volume)),
				"size": _vector(volume.size),
				"side_view": volume.side_view,
				"distance": _number(volume.distance),
			})
		elif node.name == &"Sea" and node is Node3D:
			sea_height = _number(world_transform(node as Node3D).origin.y)
		elif node.name == &"Player" and node is Node3D:
			player_start = _transform(world_transform(node as Node3D))
		elif node is Node3D and parent and parent.name in [&"Gimmicks", &"Enemies"]:
			var kind := node.scene_file_path.get_file().get_basename() if node.scene_file_path != "" else node.get_class()
			var marker := {
				"name": String(node.name),
				"kind": kind,
				"position": _vector(world_transform(node as Node3D).origin),
			}
			if node is Label3D:
				# A sign: the art puts a board behind it, so it needs the text's size and facing.
				var label := node as Label3D
				var font := label.font if label.font else ThemeDB.fallback_font
				var size := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, label.font_size)
				marker.text_size = [_number(size.x * label.pixel_size), _number(size.y * label.pixel_size)]
				marker.transform = _transform(world_transform(label))
				marker.billboard = label.billboard != BaseMaterial3D.BILLBOARD_DISABLED
			markers.append(marker)
	return {
		"stage": path,
		"sea_height": sea_height,
		"player_start": player_start,
		"pieces": pieces,
		"loops": loops,
		"camera_volumes": camera_volumes,
		"walls": walls,
		"markers": markers,
	}


static func _piece(shape: CSGShape3D, stage: Node) -> Dictionary:
	var material := shape.get("material") as Material
	var piece := {
		"name": String(shape.name),
		"path": String(stage.get_path_to(shape)),
		"transform": _transform(world_transform(shape)),
		"material": material.resource_path.get_file().get_basename() if material else "",
	}
	var simple := shape.get_children().filter(func(child: Node) -> bool: return child is CSGShape3D).is_empty()
	if simple and shape is CSGPolygon3D and (shape as CSGPolygon3D).mode == CSGPolygon3D.MODE_DEPTH:
		var polygon := shape as CSGPolygon3D
		var points: Array[Array] = []
		for point in polygon.polygon:
			points.append([_number(point.x), _number(point.y)])
		piece.type = "polygon"
		piece.polygon = points
		piece.depth = _number(polygon.depth)
	elif simple and shape is CSGBox3D:
		piece.type = "box"
		piece.size = _vector((shape as CSGBox3D).size)
	else:
		# Anything else: its triangles in the shape's own space.
		piece.type = "mesh"
		var mesh := shape.bake_static_mesh()
		var triangles: Array[Array] = []
		if mesh:
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var order := indices if not indices.is_empty() else PackedInt32Array(range(vertices.size()))
				for index in order:
					triangles.append(_vector(vertices[index]))
		piece.triangles = triangles
	return piece


## The node's transform relative to the stage's root, worked out without the node being in a tree.
static func world_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


static func _transform(transform: Transform3D) -> Dictionary:
	return {
		"x": _vector(transform.basis.x),
		"y": _vector(transform.basis.y),
		"z": _vector(transform.basis.z),
		"origin": _vector(transform.origin),
	}


static func _vector(vector: Vector3) -> Array:
	return [_number(vector.x), _number(vector.y), _number(vector.z)]


static func _number(value: float) -> float:
	return snappedf(value, PRECISION)
