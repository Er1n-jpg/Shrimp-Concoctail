class_name StationProgress
extends Control
## Small progress track showing which counter station you are standing at.

@export var count: int = 3
var current: int = 0:
	set(value):
		current = clampi(value, 0, maxi(count - 1, 0))
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	if count <= 0:
		return
	var spacing := 30.0
	var start := size.x * 0.5 - spacing * float(count - 1) * 0.5
	var y := size.y * 0.5
	if count > 1:
		draw_line(Vector2(start, y), Vector2(start + spacing * float(count - 1), y), Color(Palette.BUTTER, 0.18), 3.0)
	for i in count:
		var center := Vector2(start + spacing * float(i), y)
		if i == current:
			draw_circle(center, 12.0, Color(Palette.BUTTER, 0.14))
			draw_circle(center, 6.0, Palette.BUTTER)
		else:
			draw_circle(center, 4.5, Color(Palette.CREAM, 0.34))
