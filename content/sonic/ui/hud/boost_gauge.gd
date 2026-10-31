@tool
extends Control
## The HUD's boost gauge: ten slanted segments that fill with the gauge, brighter while boosting and
## pulsing when full. Empty segments stay as outlines, so it reads without colour too.

const SEGMENTS := 10
const GAP := 6.0
const FILL := Color(0.3, 0.85, 1.0)
const ACTIVE := Color(0.78, 0.97, 1.0)
const BACKING := Color(0.024, 0.063, 0.227, 0.7)
const OUTLINE := Color(1.0, 1.0, 1.0, 0.55)

@export_range(0.0, 100.0) var value: float = 33.0:  ## How full it is (percent).
	set(amount):
		value = amount
		queue_redraw()
@export var active: bool = false:  ## Boosting right now.
	set(on):
		active = on
		queue_redraw()


func _process(_delta: float) -> void:
	if value >= 100.0:
		queue_redraw()  # Keeps the full gauge pulsing.


func _draw() -> void:
	var slant := size.y * 0.35
	var width := (size.x - slant - GAP * (SEGMENTS - 1)) / SEGMENTS
	var filled := value / 100.0 * SEGMENTS
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0) if value >= 100.0 else 0.0
	var color := (ACTIVE if active else FILL).lerp(Color.WHITE, pulse * 0.45)
	for i in SEGMENTS:
		var x := i * (width + GAP)
		var outline := _segment(x, width, slant)
		draw_colored_polygon(outline, BACKING)
		var share := clampf(filled - i, 0.0, 1.0)
		if share > 0.0:
			draw_colored_polygon(_segment(x, width * share, slant), color)
		outline.append(outline[0])
		draw_polyline(outline, OUTLINE, 2.0, true)


## A slanted segment `width` wide starting at `x`.
func _segment(x: float, width: float, slant: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x + slant, 0.0), Vector2(x + slant + width, 0.0), Vector2(x + width, size.y), Vector2(x, size.y)])
