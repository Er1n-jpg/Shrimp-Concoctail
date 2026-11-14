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
@export var placeholder_font_size: int = 22:
	set(value):
		placeholder_font_size = value
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

## The loaded image, or null while showing the placeholder.
var texture: Texture2D

var _built := false
var _texture_rect: TextureRect
var _placeholder: Panel
var _label: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_texture_rect)
	_texture_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

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


func set_art(path: String, color: Color, text: String = "") -> void:
	art_path = path
	placeholder_color = color
	placeholder_text = text


func _refresh() -> void:
	if not _built:
		return
	texture = Art.load_texture(art_path)
	_texture_rect.texture = texture
	_texture_rect.stretch_mode = stretch
	_texture_rect.visible = texture != null
	_placeholder.visible = texture == null
	if texture != null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color(placeholder_color, 0.0 if outline_only else 1.0)
	style.border_color = placeholder_color if outline_only else placeholder_color.darkened(0.35)
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	_placeholder.add_theme_stylebox_override("panel", style)

	var light_bg := placeholder_color.get_luminance() > 0.55 and not outline_only
	_label.text = placeholder_text
	_label.add_theme_font_size_override("font_size", placeholder_font_size)
	_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1) if light_bg else Color.WHITE)
