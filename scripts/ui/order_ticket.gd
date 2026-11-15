class_name OrderTicket
extends Control
## Pinned top-right while you're at the bar: who ordered and what they SAID (never the
## recipe itself, so players have to work it out), the Vibecoder's Ask button with
## whatever it revealed, and the patience bar (which only runs at the bar).

signal patience_ran_out
signal ask_pressed

var _total := 1.0
var _left := 0.0
var _running := false
var _fill_style := StyleBoxFlat.new()

@onready var _title: Label = $Title
@onready var _body: Label = $Body
@onready var _clues: Label = $Clues
@onready var _ask_button: Button = $AskButton
@onready var _patience: ProgressBar = $Patience


func _ready() -> void:
	_ask_button.focus_mode = FOCUS_NONE
	_ask_button.pressed.connect(func() -> void: ask_pressed.emit())
	_fill_style.set_corner_radius_all(6)
	_patience.add_theme_stylebox_override("fill", _fill_style)


## `what_they_said` is the customer's hint lines (see Dialogue.build).
func show_order(customer: CustomerData, what_they_said: String, required: PackedStringArray, revealed: int, hidden: bool, patience: float) -> void:
	_title.text = "ORDER  -  %s" % customer.display_name
	_body.text = "\"%s\"" % what_they_said
	set_revealed(required, revealed, hidden)
	_total = patience
	_left = patience
	_running = false
	_update_bar()


## Hidden recipes (Vibecoder): show the ingredients revealed by asking so far.
func set_revealed(required: PackedStringArray, revealed: int, hidden: bool) -> void:
	_clues.visible = hidden
	_ask_button.visible = hidden and revealed < required.size()
	if not hidden:
		return
	var names: PackedStringArray = []
	for i in mini(revealed, required.size()):
		var ing := Database.ingredient(required[i])
		names.append(ing.display_name if ing != null else required[i])
	var left := required.size() - revealed
	if names.is_empty():
		_clues.text = "No idea what they want. Ask?"
	elif left > 0:
		_clues.text = "Clarified: %s  (+%d more)" % [", ".join(names), left]
	else:
		_clues.text = "Clarified: %s" % ", ".join(names)


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
