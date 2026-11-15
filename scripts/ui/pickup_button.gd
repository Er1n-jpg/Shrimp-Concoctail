class_name PickupButton
extends Button
## A clickable thing on the bar that isn't a priced ingredient (the cup stack).
## Shows its art (stacked `stack_count` times) with a label under it.

@export var art_path: String = ""
@export var placeholder_color: Color = Palette.BLUSH
@export var placeholder_text: String = ""
@export var label_text: String = ""
@export var art_size: Vector2 = Vector2(128, 128)
## Draw the art this many times, offset upward (a stack of cups).
@export var stack_count: int = 1
@export var stack_offset: float = 22.0
## Outline around the art (transparent = none), for dark sprites on the dark bar.
@export var outline_color: Color = Color(0, 0, 0, 0)

var _label: Label


func _ready() -> void:
	focus_mode = FOCUS_NONE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(Palette.BUTTER, 0.14)
	hover.set_corner_radius_all(14)
	for state in ["normal", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)

	var label_h := 34.0
	for i in stack_count:
		var slot := ArtSlot.new()
		slot.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(slot)
		slot.size = art_size
		slot.position = Vector2((size.x - art_size.x) / 2.0, size.y - label_h - art_size.y - i * stack_offset)
		slot.outline_color = outline_color
		slot.set_art(art_path, placeholder_color, placeholder_text)
		move_child(slot, 0)  # lower cups drawn last so they sit in front

	_label = Label.new()
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_outline_color", Palette.INK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.position = Vector2(0, size.y - label_h)
	_label.size = Vector2(size.x, label_h)


func set_label(text: String) -> void:
	label_text = text
	if _label != null:
		_label.text = text


## Screen-space center of the top item (where a picked-up thing starts its flight).
func art_center() -> Vector2:
	return global_position + Vector2(size.x / 2.0, size.y - 34.0 - art_size.y / 2.0)
