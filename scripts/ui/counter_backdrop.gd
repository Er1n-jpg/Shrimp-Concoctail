class_name CounterBackdrop
extends Control
## Wooden bar counter drawn in code. Hides itself once res://assets/ui/counter.png exists.

const WOOD := Color("45170a")
const LIP_HEIGHT := 30.0
const PLANK_WIDTH := 160.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = Art.load_texture(Art.ui("counter")) == null
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y

	# Front panel with planks and grain
	draw_rect(Rect2(0.0, LIP_HEIGHT, w, h - LIP_HEIGHT), WOOD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 70:
		var gx := rng.randf_range(0.0, w)
		var gy := rng.randf_range(LIP_HEIGHT + 10.0, h - 30.0)
		draw_line(Vector2(gx, gy), Vector2(gx + rng.randf_range(30.0, 120.0), gy), Color(Palette.MAROON, 0.45), 2.0)
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, LIP_HEIGHT), Vector2(x, h), Color(Palette.INK, 0.45), 3.0)
		x += PLANK_WIDTH

	# Warm light spilling onto the top of the panel
	for i in 6:
		draw_rect(Rect2(0.0, LIP_HEIGHT, w, 70.0 - i * 11.0), Color(Palette.ORANGE, 0.03))

	# Kick plate
	draw_rect(Rect2(0.0, h - 24.0, w, 24.0), Palette.INK)

	# Bar top lip
	draw_rect(Rect2(0.0, 0.0, w, LIP_HEIGHT), Palette.RUST)
	draw_rect(Rect2(0.0, 0.0, w, 5.0), Palette.ORANGE)
	draw_rect(Rect2(0.0, LIP_HEIGHT - 6.0, w, 6.0), Palette.MAROON)
	draw_rect(Rect2(0.0, LIP_HEIGHT, w, 8.0), Color(Palette.INK, 0.5))
