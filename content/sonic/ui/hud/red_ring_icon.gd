@tool
extends Control
## One red ring on the HUD: a thick, bright ring once found, a thin outline until then, so it reads
## by shape as well as colour.

const RED := Color(1.0, 0.18, 0.2)
const DARK := Color(0.35, 0.05, 0.08)
const EMPTY := Color(1.0, 1.0, 1.0, 0.55)

@export var found: bool = false:
	set(value):
		found = value
		queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	if found:
		var band := radius * 0.42
		draw_arc(center, radius - band * 0.5, 0.0, TAU, 32, DARK, band, true)
		draw_arc(center, radius - band * 0.58, 0.0, TAU, 32, RED, band * 0.66, true)
		draw_arc(center, radius - band * 0.58, PI * 1.05, PI * 1.5, 8, Color.WHITE, band * 0.2, true)
	else:
		draw_arc(center, radius * 0.82, 0.0, TAU, 32, EMPTY, radius * 0.16, true)
