class_name ReviewPopup
extends Control
## Star rating + review line + payout, shown where the order bubble was.
## Click it (or press Space) to skip.

signal skip_requested

@onready var _name: Label = $Name
@onready var _stars: StarRow = $Stars
@onready var _review: Label = $Review
@onready var _payout: Label = $Payout
@onready var _detail: Label = $Detail


func _ready() -> void:
	visible = false
	gui_input.connect(_on_gui_input)


func show_review(customer_name: String, stars: int, text: String, payout: int, detail: String) -> void:
	_name.text = customer_name
	_stars.stars = stars
	_review.text = "\"%s\"" % text
	_payout.text = "+$%d" % payout
	_payout.add_theme_color_override("font_color", Color(0.3, 0.85, 0.35) if payout > 0 else Color(0.9, 0.25, 0.25))
	_detail.text = detail
	visible = true

	pivot_offset = size / 2.0
	scale = Vector2(0.8, 0.8)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_popup() -> void:
	visible = false


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		skip_requested.emit()
