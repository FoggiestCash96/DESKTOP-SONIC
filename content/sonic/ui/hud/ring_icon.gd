@tool
extends Control
## The HUD's ring icon: a gold ring drawn in code, filling the control.

const GOLD := Color(1.0, 0.78, 0.15)
const SHADE := Color(0.72, 0.42, 0.05)
const SHINE := Color(1.0, 0.97, 0.75)


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	var band := radius * 0.28
	draw_arc(center, radius - band * 0.5, 0.0, TAU, 48, SHADE, band, true)
	draw_arc(center, radius - band * 0.62, 0.0, TAU, 48, GOLD, band * 0.62, true)
	draw_arc(center, radius - band * 0.62, PI * 1.05, PI * 1.45, 12, SHINE, band * 0.22, true)
