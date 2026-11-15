class_name BarBackdrop
extends Control
## Cozy speakeasy back wall drawn in code: bottle shelves, pendant lamps and a neon sign.
## Hides itself once res://assets/ui/background.png exists.

@export_multiline var neon_text: String = "SHRIMP\nCOCKTAIL"
@export var neon_rect: Rect2 = Rect2(1505, 92, 360, 150)
@export var lamp_xs: PackedFloat32Array = PackedFloat32Array([70.0, 565.0, 1472.0])
@export var shelf_ys: PackedFloat32Array = PackedFloat32Array([250.0, 395.0, 540.0])
@export var bottle_seed: int = 7
## Only the top N shelves get code-drawn bottles (-1 = all). Lower shelves stay clear for real items.
@export var bottle_shelves: int = -1

const BOTTLE_COLORS := [Palette.MAROON, Palette.GREEN, Palette.RUST, Palette.ORANGE, Palette.TAUPE, Palette.SLATE, Palette.PINK, Palette.BUTTER]


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = Art.load_texture(Art.ui("background")) == null
	resized.connect(queue_redraw)


func _draw() -> void:
	_draw_wall()
	_draw_shelves()
	_draw_lamps()
	_draw_neon()


func _draw_wall() -> void:
	var strip := 12.0
	var y := 0.0
	while y < size.y:
		var t := clampf(y / 560.0, 0.0, 1.0)
		draw_rect(Rect2(0.0, y, size.x, strip + 1.0), Palette.INK.lerp(Palette.DARK_BROWN, t))
		y += strip
	# Wall panels
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 64.0), Vector2(x, size.y), Color(Palette.MAROON, 0.25), 2.0)
		x += 240.0


func _draw_shelves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = bottle_seed
	var prev_y := 70.0
	var shelf_index := 0
	for shelf_y in shelf_ys:
		var max_h := minf(shelf_y - prev_y - 14.0, 100.0)
		var x := 14.0 + rng.randf_range(0.0, 20.0)
		var with_bottles := bottle_shelves < 0 or shelf_index < bottle_shelves
		shelf_index += 1
		while with_bottles and x < size.x - 30.0:
			var w := rng.randf_range(18.0, 32.0)
			var h := rng.randf_range(max_h * 0.45, max_h)
			var color: Color = BOTTLE_COLORS[rng.randi() % BOTTLE_COLORS.size()]
			if rng.randf() < 0.25:
				_draw_jar(Vector2(x, shelf_y), w * 1.4, h * 0.5, color)
				x += w * 1.4
			else:
				_draw_bottle(Vector2(x, shelf_y), w, h, color)
				x += w
			x += rng.randf_range(6.0, 22.0)
		# Shelf plank
		draw_rect(Rect2(0.0, shelf_y, size.x, 10.0), Palette.MAROON)
		draw_rect(Rect2(0.0, shelf_y, size.x, 2.0), Color(Palette.RUST, 0.7))
		draw_rect(Rect2(0.0, shelf_y + 10.0, size.x, 8.0), Color(Palette.INK, 0.5))
		prev_y = shelf_y


func _draw_bottle(bottom_left: Vector2, w: float, h: float, color: Color) -> void:
	var body_h := h * 0.65
	var neck_w := w * 0.36
	var neck_h := h - body_h
	var c := Color(color.darkened(0.25), 0.8)
	draw_rect(Rect2(bottom_left.x, bottom_left.y - body_h, w, body_h), c)
	draw_rect(Rect2(bottom_left.x + (w - neck_w) / 2.0, bottom_left.y - h, neck_w, neck_h), c)
	draw_rect(Rect2(bottom_left.x + (w - neck_w) / 2.0 - 1.0, bottom_left.y - h - 4.0, neck_w + 2.0, 5.0), Color(Palette.INK, 0.7))
	# Label + shine
	draw_rect(Rect2(bottom_left.x + 2.0, bottom_left.y - body_h * 0.7, w - 4.0, body_h * 0.3), Color(Palette.CREAM, 0.18))
	draw_rect(Rect2(bottom_left.x + 3.0, bottom_left.y - body_h + 4.0, 3.0, body_h - 8.0), Color(Palette.CREAM, 0.22))


func _draw_jar(bottom_left: Vector2, w: float, h: float, color: Color) -> void:
	var c := Color(color.darkened(0.25), 0.8)
	draw_rect(Rect2(bottom_left.x, bottom_left.y - h, w, h), c)
	draw_rect(Rect2(bottom_left.x - 2.0, bottom_left.y - h - 6.0, w + 4.0, 7.0), Color(Palette.SLATE, 0.9))
	draw_rect(Rect2(bottom_left.x + 3.0, bottom_left.y - h + 3.0, 3.0, h - 6.0), Color(Palette.CREAM, 0.22))


func _draw_lamps() -> void:
	for x in lamp_xs:
		var bulb := Vector2(x, 90.0)
		# Warm glow
		var r := 320.0
		while r > 30.0:
			draw_circle(bulb, r, Color(Palette.ORANGE, 0.03))
			r -= 22.0
		# Cord + shade
		draw_line(Vector2(x, 64.0), Vector2(x, 70.0), Palette.INK, 3.0)
		var shade := PackedVector2Array([
			Vector2(x - 10.0, 70.0), Vector2(x + 10.0, 70.0),
			Vector2(x + 34.0, 90.0), Vector2(x - 34.0, 90.0)])
		draw_colored_polygon(shade, Palette.RUST)
		draw_line(Vector2(x - 34.0, 90.0), Vector2(x + 34.0, 90.0), Palette.ORANGE, 4.0)
		draw_circle(bulb, 7.0, Palette.BUTTER)


func _draw_neon() -> void:
	if neon_text.is_empty():
		return
	# Backing board with a pink glow edge
	draw_rect(neon_rect, Color(Palette.INK, 0.7))
	for i in 4:
		var grow := float(i) * 3.0
		draw_rect(neon_rect.grow(grow), Color(Palette.PINK, 0.5 - i * 0.12), false, 3.0)

	var font := get_theme_default_font()
	var lines := neon_text.split("\n")
	var font_size := 66
	var line_h := font_size * 1.05
	var top := neon_rect.position.y + (neon_rect.size.y - line_h * lines.size()) / 2.0 + font_size * 0.85
	for i in lines.size():
		var pos := Vector2(neon_rect.position.x, top + i * line_h)
		for glow in [18, 10]:
			draw_string_outline(font, pos, lines[i], HORIZONTAL_ALIGNMENT_CENTER, neon_rect.size.x, font_size, glow, Color(Palette.PINK, 0.18))
		draw_string(font, pos, lines[i], HORIZONTAL_ALIGNMENT_CENTER, neon_rect.size.x, font_size, Palette.BLUSH)
