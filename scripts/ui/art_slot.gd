class_name ArtSlot
extends Control
## Shows a drop-in image, or a labeled colored box until that image exists.
## `art_path` has no extension: "res://assets/ui/shrimp" finds shrimp.png / .webp / .jpg / .svg.

@export var art_path: String = "":
	set(value):
		art_path = value
		_refresh()
@export var placeholder_color: Color = Color(0.45, 0.45, 0.5):
	set(value):
		placeholder_color = value
		_refresh()
@export var placeholder_text: String = "":
	set(value):
		placeholder_text = value
		_refresh()
@export var placeholder_font_size: int = 28:
	set(value):
		placeholder_font_size = value
		_refresh()
## Placeholder border. Fully transparent = automatic (a darker shade of placeholder_color).
@export var placeholder_border_color: Color = Color(0, 0, 0, 0):
	set(value):
		placeholder_border_color = value
		_refresh()
@export var placeholder_border_width: int = 4:
	set(value):
		placeholder_border_width = value
		_refresh()
@export var placeholder_corner_radius: int = 14:
	set(value):
		placeholder_corner_radius = value
		_refresh()
@export var placeholder_shadow: int = 0:
	set(value):
		placeholder_shadow = value
		_refresh()
## Only draw an outline when there's no art (the cup uses this so the liquid shows through).
@export var outline_only: bool = false:
	set(value):
		outline_only = value
		_refresh()
@export var stretch: TextureRect.StretchMode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
	set(value):
		stretch = value
		_refresh()
## Mirror the image horizontally (e.g. to make a character face the other way).
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		_refresh()
## 9-slice the image (for boxes/bubbles): border sizes in source pixels as
## (left, top, right, bottom). Corners stay intact, edges and middle stretch.
## All zero = off (image is just stretched/fit using `stretch`).
@export var nine_patch_margins: Vector4i = Vector4i.ZERO:
	set(value):
		nine_patch_margins = value
		_refresh()
## With 9-slicing on: how many screen pixels per art pixel (keeps pixel art crisp).
@export_range(1, 16) var pixel_scale: int = 1:
	set(value):
		pixel_scale = value
		_refresh()

## The loaded image, or null while showing the placeholder.
var texture: Texture2D

var _built := false
var _texture_rect: TextureRect
var _nine_patch: NinePatchRect
var _placeholder: Panel
var _label: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_texture_rect)
	_texture_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 9-slice drawn at 1/pixel_scale size, then scaled up so art pixels stay square.
	_nine_patch = NinePatchRect.new()
	_nine_patch.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_nine_patch)
	resized.connect(_layout_nine_patch)

	_placeholder = Panel.new()
	_placeholder.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_placeholder)
	_placeholder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_placeholder.add_child(_label)
	_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 6)

	_built = true
	_refresh()


func _layout_nine_patch() -> void:
	if not _built:
		return
	_nine_patch.position = Vector2.ZERO
	_nine_patch.scale = Vector2(pixel_scale, pixel_scale)
	_nine_patch.size = size / float(pixel_scale)


func set_art(path: String, color: Color, text: String = "") -> void:
	art_path = path
	placeholder_color = color
	placeholder_text = text


func _refresh() -> void:
	if not _built:
		return
	texture = Art.load_texture(art_path)
	var sliced := texture != null and nine_patch_margins != Vector4i.ZERO
	_texture_rect.texture = texture
	_texture_rect.stretch_mode = stretch
	_texture_rect.flip_h = flip_h
	_texture_rect.visible = texture != null and not sliced
	_nine_patch.texture = texture
	_nine_patch.patch_margin_left = nine_patch_margins.x
	_nine_patch.patch_margin_top = nine_patch_margins.y
	_nine_patch.patch_margin_right = nine_patch_margins.z
	_nine_patch.patch_margin_bottom = nine_patch_margins.w
	_nine_patch.visible = sliced
	_layout_nine_patch()
	_placeholder.visible = texture == null
	if texture != null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color(placeholder_color, 0.0 if outline_only else placeholder_color.a)
	if placeholder_border_color.a > 0.0:
		style.border_color = placeholder_border_color
	else:
		style.border_color = placeholder_color if outline_only else placeholder_color.darkened(0.35)
	style.set_border_width_all(placeholder_border_width)
	style.set_corner_radius_all(placeholder_corner_radius)
	if placeholder_shadow > 0:
		style.shadow_color = Color(Palette.INK, 0.55)
		style.shadow_size = placeholder_shadow
		style.shadow_offset = Vector2(0, placeholder_shadow * 0.5)
	_placeholder.add_theme_stylebox_override("panel", style)

	var light_bg := placeholder_color.get_luminance() > 0.55 and not outline_only
	_label.text = placeholder_text
	_label.add_theme_font_size_override("font_size", placeholder_font_size)
	_label.add_theme_color_override("font_color", Palette.TEXT_DARK if light_bg else Palette.TEXT_LIGHT)
