class_name SpeechBubble
extends Control
## A dialogue box: speaker name, a typewriter line, and a blinking "next" arrow.
## Used for both the customer's bubble and the shrimp's box.

const CHARS_PER_SECOND := 70.0

var _type_tween: Tween
var _blink := 0.0

@onready var _name: Label = $Name
@onready var _text: Label = $Text
@onready var _next: Control = $Next


func _ready() -> void:
	visible = false
	_next.draw.connect(_draw_next)


func show_line(speaker: String, text: String) -> void:
	_name.text = speaker
	_text.text = text
	_text.visible_ratio = 0.0
	if not visible:
		visible = true
		pivot_offset = Vector2(size.x * 0.2, size.y)
		scale = Vector2(0.85, 0.85)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _type_tween != null:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, maxf(text.length() / CHARS_PER_SECOND, 0.1))


func is_typing() -> bool:
	return visible and _text.visible_ratio < 1.0


func finish_typing() -> void:
	if _type_tween != null:
		_type_tween.kill()
	_text.visible_ratio = 1.0


func hide_bubble() -> void:
	visible = false


func _process(delta: float) -> void:
	_blink += delta
	_next.visible = visible and not is_typing() and fmod(_blink, 0.8) < 0.55


func _draw_next() -> void:
	var s := _next.size
	var points := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x / 2.0, s.y)])
	_next.draw_colored_polygon(points, Palette.DARK_BROWN)
