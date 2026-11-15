class_name SoftShadow
extends Control
## A soft, layered elliptical contact shadow. Purely visual and mouse-transparent.

@export var shadow_color: Color = Color(0.02, 0.01, 0.005, 0.55)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var radius := size * 0.5
	if radius.x <= 0.0 or radius.y <= 0.0:
		return
	# Draw wide + faint first, then tighter + darker. The layers stack into a
	# soft edge instead of a hard sprite rectangle.
	for i in range(7, 0, -1):
		var t := float(i) / 7.0
		var alpha := shadow_color.a * (1.0 - t) * 0.22
		_draw_ellipse(radius * t, Color(shadow_color, alpha))


func _draw_ellipse(radii: Vector2, color: Color) -> void:
	draw_set_transform(size * 0.5, 0.0, Vector2(1.0, radii.y / maxf(radii.x, 0.001)))
	draw_circle(Vector2.ZERO, radii.x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
