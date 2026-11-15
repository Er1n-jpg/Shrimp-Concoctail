class_name OrderTicket
extends Control
## Pinned top-right while you're at the bar: who ordered, the recipe icons,
## the Vibecoder's Ask button, and the patience bar (which only runs at the bar).

signal patience_ran_out
signal ask_pressed

const ICON_SIZE := Vector2(64, 64)
const HIDDEN_COLOR := Palette.SLATE

var _total := 1.0
var _left := 0.0
var _running := false
var _fill_style := StyleBoxFlat.new()

@onready var _title: Label = $Title
@onready var _icons: HBoxContainer = $Icons
@onready var _ask_button: Button = $AskButton
@onready var _patience: ProgressBar = $Patience


func _ready() -> void:
	_ask_button.focus_mode = FOCUS_NONE
	_ask_button.pressed.connect(func() -> void: ask_pressed.emit())
	_fill_style.set_corner_radius_all(6)
	_patience.add_theme_stylebox_override("fill", _fill_style)


func show_order(customer: CustomerData, required: PackedStringArray, revealed: int, hidden: bool, patience: float) -> void:
	_title.text = "ORDER  -  %s" % customer.display_name
	set_icons(required, revealed, hidden)
	_total = patience
	_left = patience
	_running = false
	_update_bar()


func set_icons(required: PackedStringArray, revealed: int, hidden: bool) -> void:
	for child in _icons.get_children():
		child.queue_free()
	for i in required.size():
		var slot := ArtSlot.new()
		slot.custom_minimum_size = ICON_SIZE
		slot.placeholder_font_size = 15
		slot.placeholder_corner_radius = 8
		slot.placeholder_border_width = 3
		var ing := Database.ingredient(required[i])
		if (hidden and i >= revealed) or ing == null:
			slot.set_art("", HIDDEN_COLOR, "?")
			slot.placeholder_font_size = 40
		else:
			slot.set_art(Art.ingredient(ing.id), ing.color, ing.display_name)
			slot.tooltip_text = ing.display_name
		_icons.add_child(slot)
	_ask_button.visible = hidden and revealed < required.size()


func can_ask() -> bool:
	return _running and _ask_button.visible


func start() -> void:
	_running = true


func stop() -> void:
	_running = false


func time_left_ratio() -> float:
	return clampf(_left / _total, 0.0, 1.0)


func spend(seconds: float) -> void:
	_left -= seconds
	_update_bar()


func _process(delta: float) -> void:
	if not _running:
		return
	_left -= delta
	_update_bar()
	if _left <= 0.0:
		_running = false
		patience_ran_out.emit()


func _update_bar() -> void:
	var ratio := time_left_ratio()
	_patience.value = ratio * 100.0
	if ratio < 0.5:
		_fill_style.bg_color = Palette.RUST.lerp(Palette.ORANGE, ratio * 2.0)
	else:
		_fill_style.bg_color = Palette.ORANGE.lerp(Palette.LIME, (ratio - 0.5) * 2.0)
