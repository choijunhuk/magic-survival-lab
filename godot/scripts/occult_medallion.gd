extends Control

# Decorative ink seal on the choice overlay. It intentionally has no input.
func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.47
	var rim := PackedVector2Array()
	for i in range(49):
		var angle := TAU * float(i) / 48.0
		var wobble := 1.0 + 0.035 * sin(angle * 13.0) + 0.022 * cos(angle * 23.0)
		rim.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble)
	draw_colored_polygon(rim, Color(0.012, 0.014, 0.012, 0.94))
	draw_polyline(rim, Color(0.17, 0.18, 0.16, 0.88), 1.0, true)
	var ink := Color(0.55, 0.56, 0.52, 0.76)
	for rotation in [0.0]:
		var corners := PackedVector2Array()
		for i in range(8):
			var index := (i * 3) % 7
			var angle: float = -PI * 0.5 + rotation + TAU * float(index) / 7.0
			corners.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.82)
		var star := PackedVector2Array()
		for i in range(7):
			var from_point := corners[i]
			var to_point := corners[i + 1]
			var normal := (to_point - from_point).normalized().orthogonal()
			for step_index in range(4):
				var fraction := float(step_index) / 4.0
				var wobble := sin(float(i * 7 + step_index * 5) + rotation * 11.0) * 0.8 if step_index > 0 else 0.0
				star.append(from_point.lerp(to_point, fraction) + normal * wobble)
		star.append(corners[7])
		draw_polyline(star, ink, 1.2, true)
	draw_circle(center, radius * 0.18, Color(0.012, 0.014, 0.012))
	draw_arc(center, radius * 0.20, 0.0, TAU, 24, ink, 1.1, true)
	draw_arc(center, radius * 0.76, 0.0, TAU, 48, Color(0.38, 0.40, 0.37, 0.57), 1.0, true)
