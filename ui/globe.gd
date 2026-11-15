class_name Globe
extends Control
## Globo di vita/risorsa in stile Diablo, disegnato a mano (sostituibile con una texture).

var value := 1.0
var max_value := 1.0
var fill_color := Color(0.8, 0.1, 0.1)
var caption := ""


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var c := size * 0.5
	draw_circle(c, r + 4.0, Color(0.55, 0.42, 0.2))
	draw_circle(c, r + 1.5, Color(0.25, 0.18, 0.08))
	draw_circle(c, r, Color(0.04, 0.03, 0.03))
	var f := clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	if f > 0.002:
		var s := clampf(1.0 - 2.0 * f, -1.0, 1.0)
		var a0 := asin(s)
		var a1 := PI - a0
		var pts := PackedVector2Array()
		var n := 48
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		if pts.size() >= 3:
			draw_colored_polygon(pts, fill_color)
			draw_colored_polygon(pts, Color(1, 1, 1, 0.0))
	draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.22, Color(1, 1, 1, 0.1))
	var font := get_theme_default_font()
	var txt := "%d / %d" % [roundi(value), roundi(max_value)]
	draw_string_outline(font, Vector2(0, c.y + 6), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, 4, Color.BLACK)
	draw_string(font, Vector2(0, c.y + 6), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)
	if caption != "":
		draw_string_outline(font, Vector2(0, size.y - 2), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, 4, Color.BLACK)
		draw_string(font, Vector2(0, size.y - 2), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.9, 0.85, 0.7))
