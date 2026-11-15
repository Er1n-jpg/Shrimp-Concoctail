class_name OrderBubble
extends Control
## Speech bubble with the customer's order line and a ticket of the required ingredients.
## Background art: res://assets/ui/speech_bubble.png (stretched to fit).

signal ask_pressed

const TICKET_ICON_SIZE := Vector2(64, 64)
const HIDDEN_COLOR := Palette.SLATE

@onready var _text: Label = $Text
@onready var _ticket: HBoxContainer = $Ticket
@onready var _ask_button: Button = $AskButton


func _ready() -> void:
	visible = false
	_ask_button.focus_mode = FOCUS_NONE
	_ask_button.pressed.connect(func() -> void: ask_pressed.emit())


func show_order(text: String, required: PackedStringArray, revealed: int, hidden: bool) -> void:
	_text.text = text
	_text.visible_ratio = 0.0
	set_ticket(required, revealed, hidden)
	visible = true

	pivot_offset = Vector2(0.0, size.y)
	scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_text, "visible_ratio", 1.0, clampf(text.length() * 0.012, 0.15, 0.7))


func set_ticket(required: PackedStringArray, revealed: int, hidden: bool) -> void:
	for child in _ticket.get_children():
		child.queue_free()
	for i in required.size():
		var slot := ArtSlot.new()
		slot.custom_minimum_size = TICKET_ICON_SIZE
		slot.placeholder_font_size = 15
		var ing := Database.ingredient(required[i])
		if (hidden and i >= revealed) or ing == null:
			slot.set_art("", HIDDEN_COLOR, "?")
			slot.placeholder_font_size = 52
		else:
			slot.set_art(Art.ingredient(ing.id), ing.color, ing.display_name)
		_ticket.add_child(slot)
	_ask_button.visible = hidden and revealed < required.size()


func can_ask() -> bool:
	return visible and _ask_button.visible


func hide_bubble() -> void:
	visible = false
