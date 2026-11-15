class_name StationArrow
extends Button
## Big, readable station arrow at the side of the bar view. The matching arrow
## on the other side is handled by Main. Drawn with the game's brass/ink palette.

@export var direction: int = 1
@export var key_hint: String = "D"


func _ready() -> void:
	focus_mode = FOCUS_NONE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	text = ">" if direction > 0 else "<"
	tooltip_text = ("Next station  [%s]" if direction > 0 else "Previous station  [%s]") % key_hint
	add_theme_font_size_override("font_size", 92)
	add_theme_color_override("font_color", Palette.BUTTER)
	add_theme_color_override("font_hover_color", Palette.CREAM)
	add_theme_color_override("font_pressed_color", Palette.BLUSH)
	add_theme_color_override("font_disabled_color", Color(Palette.BUTTER, 0.22))
	add_theme_color_override("font_outline_color", Palette.INK)
	add_theme_constant_override("outline_size", 10)
	pivot_offset = size / 2.0

	_apply_styles()
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))


func _apply_styles() -> void:
	var normal := _style(Color(Palette.INK, 0.58), Color(Palette.BUTTER, 0.42))
	var hover := _style(Color(Palette.DARK_BROWN, 0.82), Color(Palette.BUTTER, 0.9))
	var pressed := _style(Color(Palette.MAROON, 0.92), Palette.ORANGE)
	var disabled := _style(Color(Palette.INK, 0.24), Color(Palette.BUTTER, 0.1))
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", disabled)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(3)
	box.set_corner_radius_all(30)
	box.shadow_color = Color(Palette.INK, 0.55)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 6)
	return box


func _hover(on: bool) -> void:
	if disabled:
		return
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.07, 1.07) if on else Vector2.ONE, 0.14)
