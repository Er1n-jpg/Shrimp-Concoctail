class_name StarRow
extends Control
## Draws a row of 5 stars (no font or art needed).

@export var stars: int = 0:
	set(value):
		stars = value
		queue_redraw()
@export var filled_color: Color = Palette.BUTTER
@export var empty_color: Color = Color(Palette.TAUPE, 0.35)
@export var outline_color: Color = Palette.DARK_BROWN

const COUNT := 5


func _draw() -> void:
	var cell := minf(size.y, size.x / COUNT)
	var radius := cell * 0.46
	var start_x := (size.x - cell * COUNT) / 2.0
	for i in COUNT:
		var center := Vector2(start_x + cell * (i + 0.5), size.y / 2.0)
		var points := _star_points(center, radius)
		draw_colored_polygon(points, filled_color if i < stars else empty_color)
		points.append(points[0])
		draw_polyline(points, outline_color, 3.0, true)


func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 10:
		var r := radius if k % 2 == 0 else radius * 0.45
		var angle := -PI / 2.0 + k * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
