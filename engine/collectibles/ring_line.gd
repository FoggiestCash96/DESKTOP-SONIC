@tool
class_name RingLine
extends Node3D
## A row of rings along this node's -Z axis, straight or arched like a jump. Turn the node to aim
## it. The rings are created when the node is ready, in the editor too, and are never saved.

const RING_SCENE := preload("res://engine/collectibles/ring.tscn")

@export_range(1, 100) var count: int = 5:
	set(value):
		count = value
		_rebuild()
@export var spacing: float = 1.5:  ## Distance between neighbouring rings (m).
	set(value):
		spacing = value
		_rebuild()
@export var arc_height: float = 0.0:  ## How high the row arches over its middle (m). 0 is a straight row.
	set(value):
		arc_height = value
		_rebuild()

var _rings: Array[Node3D] = []


func _ready() -> void:
	_build()


## Where ring `index` of `total` sits, in the row's own space.
static func ring_position(index: int, total: int, step: float, arc: float) -> Vector3:
	var t := float(index) / float(maxi(total - 1, 1))
	return Vector3(0.0, arc * 4.0 * t * (1.0 - t), -step * index)


func _rebuild() -> void:
	if is_node_ready():
		_build()


func _build() -> void:
	for ring in _rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_rings.clear()
	for i in count:
		var ring := RING_SCENE.instantiate() as Node3D
		ring.position = ring_position(i, count, spacing, arc_height)
		add_child(ring)
		_rings.append(ring)
