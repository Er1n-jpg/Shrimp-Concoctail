class_name StationDividers
extends Control
## Subtle brass seams that separate the counter into ingredient stations.

@export var boundaries: PackedFloat32Array = PackedFloat32Array([1920.0, 3840.0])
@export var top_y: float = 86.0
@export var counter_y: float = 690.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	for x in boundaries:
		# Faint seam up the back wall.
		draw_rect(Rect2(x - 1.0, top_y, 2.0, counter_y - top_y), Color(Palette.BUTTER, 0.06))
		# Little brass pin at the top.
		draw_circle(Vector2(x, top_y + 5.0), 5.0, Color(Palette.BUTTER, 0.24))
		draw_circle(Vector2(x, top_y + 5.0), 2.0, Color(Palette.CREAM, 0.45))
		# Warm glint where the seam meets the counter top.
		draw_rect(Rect2(x - 46.0, counter_y - 2.0, 92.0, 3.0), Color(Palette.ORANGE, 0.16))
