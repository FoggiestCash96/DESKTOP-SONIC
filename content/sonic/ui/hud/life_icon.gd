@tool
extends Control
## The HUD's lives icon: a stand-in Sonic head drawn in code (quills, muzzle and eyes) until the art
## pass brings a real one.

const BLUE := Color(0.14, 0.36, 0.95)
const DEEP := Color(0.06, 0.16, 0.5)
const SKIN := Color(1.0, 0.82, 0.62)
const EYE := Color(1.0, 1.0, 1.0)
const PUPIL := Color(0.05, 0.12, 0.08)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5 + Vector2(s * 0.04, s * 0.04)
	var r := s * 0.32
	# Quills sweeping back and up, behind the head.
	for i in 3:
		var angle := deg_to_rad(150.0 + i * 32.0)
		var root := c + Vector2(cos(angle), -sin(angle)) * r * 0.45
		var tip := c + Vector2(cos(angle), -sin(angle)) * r * 1.55
		var side := Vector2(-sin(angle), -cos(angle)) * r * 0.42
		draw_colored_polygon(PackedVector2Array([root + side, tip, root - side]), DEEP)
		draw_colored_polygon(PackedVector2Array([root + side * 0.8, tip.lerp(c, 0.08), root - side * 0.8]), BLUE)
	draw_circle(c, r * 1.04, DEEP)
	draw_circle(c, r, BLUE)
	# Muzzle and eyes, facing right.
	draw_circle(c + Vector2(r * 0.42, r * 0.38), r * 0.42, SKIN)
	draw_circle(c + Vector2(r * 0.28, -r * 0.18), r * 0.3, EYE)
	draw_circle(c + Vector2(r * 0.66, -r * 0.16), r * 0.24, EYE)
	draw_circle(c + Vector2(r * 0.36, -r * 0.14), r * 0.12, PUPIL)
	draw_circle(c + Vector2(r * 0.7, -r * 0.12), r * 0.1, PUPIL)
	draw_circle(c + Vector2(r * 0.86, r * 0.3), r * 0.1, PUPIL)
