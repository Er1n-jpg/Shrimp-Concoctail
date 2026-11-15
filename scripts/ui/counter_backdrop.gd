class_name CounterBackdrop
extends Control
## Warm wooden bar counter drawn in code. The top is a lit perspective surface and
## the front is a darker panel with grain, a brass rail and a kick plate.
## Hides itself once res://assets/ui/counter.png exists.

const BACK_WOOD := Color("2b0d05")
const TOP_WOOD := Color("7d3819")
const FRONT_WOOD := Color("3d1508")
const FRONT_DARK := Color("250b04")
const SURFACE_DEPTH := 300.0
const MIN_DEPTH := 118.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = Art.load_texture(Art.ui("counter")) == null
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var depth := clampf(h * 0.56, MIN_DEPTH, SURFACE_DEPTH)
	_draw_surface(w, depth)
	_draw_front(w, h, depth)


func _draw_surface(w: float, depth: float) -> void:
	# Back-to-front gradient: the near edge catches the pendant lights.
	var bands := 42
	for i in bands:
		var t0 := float(i) / float(bands)
		var t1 := float(i + 1) / float(bands)
		var color := BACK_WOOD.lerp(TOP_WOOD, pow(t0, 1.3))
		draw_rect(Rect2(0.0, depth * t0, w, depth * (t1 - t0) + 1.0), color)

	# Planks run away from the camera, with a light perspective flare at the front.
	var planks := maxi(8, int(w / 220.0))
	for i in planks + 1:
		var back_x := float(i) * w / float(planks)
		var front_x := w * 0.5 + (back_x - w * 0.5) * 1.035
		draw_line(Vector2(back_x, 0.0), Vector2(front_x, depth), Color(Palette.INK, 0.22), 3.0)
		draw_line(Vector2(back_x + 4.0, 0.0), Vector2(front_x + 4.0, depth), Color(Palette.ORANGE, 0.045), 2.0)

	# Loose grain and a few knots in the wood.
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in int(w / 90.0):
		var x := rng.randf_range(0.0, w)
		var y := rng.randf_range(12.0, depth - 20.0)
		var length := rng.randf_range(60.0, 190.0)
		var points := PackedVector2Array([
			Vector2(x, y),
			Vector2(x + length * 0.33, y + rng.randf_range(-4.0, 4.0)),
			Vector2(x + length * 0.66, y + rng.randf_range(-6.0, 6.0)),
			Vector2(x + length, y + rng.randf_range(-3.0, 3.0)),
		])
		draw_polyline(points, Color(Palette.MAROON, 0.28), 2.0, true)

	# Warm pools of light on the counter surface.
	var count := maxi(1, int(w / 800.0) + 1)
	for i in count:
		var center := Vector2(400.0 + float(i) * 800.0, depth * 0.63)
		_ellipse(center, Vector2(315.0, depth * 0.36), Color(Palette.ORANGE, 0.05))
		_ellipse(center, Vector2(190.0, depth * 0.24), Color(Palette.BUTTER, 0.025))

	# Back lip and the bright bullnose edge at the front.
	draw_rect(Rect2(0.0, 0.0, w, 9.0), Color(Palette.INK, 0.55))
	draw_rect(Rect2(0.0, 9.0, w, 3.0), Color(Palette.ORANGE, 0.2))
	draw_rect(Rect2(0.0, depth - 17.0, w, 17.0), Color(Palette.MAROON, 0.55))
	draw_rect(Rect2(0.0, depth - 17.0, w, 5.0), Color(Palette.BUTTER, 0.22))
	draw_rect(Rect2(0.0, depth - 2.0, w, 2.0), Color(Palette.INK, 0.5))


func _draw_front(w: float, h: float, depth: float) -> void:
	draw_rect(Rect2(0.0, depth, w, h - depth), FRONT_WOOD)
	draw_rect(Rect2(0.0, depth, w, 10.0), Color(Palette.INK, 0.38))

	# Vertical planks.
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, depth + 8.0), Vector2(x, h), Color(Palette.INK, 0.4), 3.0)
		draw_line(Vector2(x + 4.0, depth + 14.0), Vector2(x + 4.0, h - 26.0), Color(Palette.ORANGE, 0.045), 2.0)
		x += 160.0

	# Grain in the front panel.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 90:
		var gx := rng.randf_range(0.0, w)
		var gy := rng.randf_range(depth + 18.0, h - 30.0)
		draw_line(Vector2(gx, gy), Vector2(gx + rng.randf_range(30.0, 130.0), gy), Color(Palette.MAROON, 0.35), 2.0)

	# Warm light spilling over the top of the front panel.
	for i in 7:
		var band_h := 46.0 - float(i) * 6.0
		draw_rect(Rect2(0.0, depth + 8.0, w, band_h), Color(Palette.ORANGE, 0.022))

	# Brass foot rail.
	draw_rect(Rect2(0.0, h - 103.0, w, 7.0), Color(Palette.BUTTER, 0.12))
	draw_rect(Rect2(0.0, h - 103.0, w, 2.0), Color(Palette.CREAM, 0.2))
	draw_rect(Rect2(0.0, h - 96.0, w, 3.0), Color(Palette.INK, 0.5))

	# Kick plate.
	draw_rect(Rect2(0.0, h - 25.0, w, 25.0), FRONT_DARK)
	draw_rect(Rect2(0.0, h - 25.0, w, 3.0), Color(Palette.ORANGE, 0.16))
	draw_rect(Rect2(0.0, h - 3.0, w, 3.0), Palette.INK)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radii.y / maxf(radii.x, 0.001)))
	draw_circle(Vector2.ZERO, radii.x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
