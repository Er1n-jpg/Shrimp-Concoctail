class_name BarScroller
extends Control
## A little scroll bar showing where you are along the bar. Click or drag to jump.

signal scrolled(ratio: float)

## 0 = far left, 1 = far right.
var ratio: float = 0.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
## How much of the bar fits on screen (thumb width as a fraction of the track).
var page: float = 0.5:
	set(value):
		page = clampf(value, 0.05, 1.0)
		queue_redraw()

var _dragging := false


func _ready() -> void:
	mouse_default_cursor_shape = CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		if button.pressed:
			_jump_to(button.position.x)
		accept_event()
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_jump_to(motion.position.x)
		accept_event()


func _jump_to(x: float) -> void:
	var thumb_w := size.x * page
	var r := (x - thumb_w / 2.0) / maxf(size.x - thumb_w, 1.0)
	ratio = r
	scrolled.emit(ratio)


func _draw() -> void:
	var track := Rect2(Vector2.ZERO, size)
	draw_style_box(_box(Color(Palette.INK, 0.75), Palette.DARK_BROWN), track)
	var thumb_w := size.x * page
	var thumb := Rect2((size.x - thumb_w) * ratio, 0.0, thumb_w, size.y)
	draw_style_box(_box(Palette.ORANGE, Palette.DARK_BROWN), thumb)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	return box
