class_name CupTray
extends Control
## Pinned bottom-left while you're at the bar: the cup, what's in it, the cost,
## and the Shake (hold) / Serve / Trash buttons.

signal serve_pressed
signal trash_pressed
signal shake_finished
## Tried to shake/serve when that isn't possible yet. Carries a hint for a toast.
signal blocked(reason: String)

const SHAKE_TIME := 1.0
const ICON_SIZE := Vector2(64, 64)

## Buttons only work while at the bar.
var active: bool = false:
	set(value):
		active = value
		_refresh()
var max_payout: int = 0:
	set(value):
		max_payout = value
		_refresh()

var _shaking := false
var _shake_progress := 0.0
var _last_pour_count := 0

@onready var cup: Cup = $Cup
@onready var _icons: GridContainer = $Icons
@onready var _cost: Label = $CostLabel
@onready var _hint: Label = $Hint
@onready var _shake_bar: ProgressBar = $ShakeBar
@onready var _shake_button: Button = $Buttons/Shake
@onready var _serve_button: Button = $Buttons/Serve
@onready var _trash_button: Button = $Buttons/Trash


func _ready() -> void:
	for button in [_shake_button, _serve_button, _trash_button]:
		button.focus_mode = FOCUS_NONE
	_shake_button.button_down.connect(start_shake)
	_shake_button.button_up.connect(stop_shake)
	_serve_button.pressed.connect(func() -> void: try_serve())
	_trash_button.pressed.connect(func() -> void: trash_pressed.emit())
	cup.changed.connect(_refresh)
	_refresh()


## Fresh, cup-less tray for a new customer.
func reset() -> void:
	stop_shake()
	_shake_progress = 0.0
	cup.clear()
	cup.present = false


func can_serve() -> bool:
	return active and cup.present and cup.has_drink() and cup.shaken


func try_serve() -> void:
	if not active:
		return
	if not cup.present:
		blocked.emit("Grab a cup first!")
	elif not cup.has_drink():
		blocked.emit("The cup's empty!")
	elif not cup.shaken:
		blocked.emit("Shake it first! (hold S)")
	else:
		serve_pressed.emit()


func start_shake() -> void:
	if not active:
		return
	if not cup.present:
		blocked.emit("Grab a cup first!")
		return
	if not cup.has_drink():
		blocked.emit("Add something to shake!")
		return
	if cup.shaken:
		return
	_shaking = true
	Sfx.play("shake")


func stop_shake() -> void:
	if _shaking:
		cup.stop_shake()
	_shaking = false


func _process(delta: float) -> void:
	if not _shaking:
		return
	_shake_progress += delta
	cup.shake_step(delta, _shake_progress / SHAKE_TIME)
	_shake_bar.value = _shake_progress / SHAKE_TIME * 100.0
	if _shake_progress >= SHAKE_TIME:
		_shaking = false
		_shake_progress = 0.0
		cup.finish_shake()
		Sfx.play("shake_done")
		shake_finished.emit()


func _refresh() -> void:
	if not is_node_ready():
		return
	# Adding an ingredient after (or during) shaking means shaking again from scratch.
	if cup.layers.size() != _last_pour_count:
		_last_pour_count = cup.layers.size()
		_shake_progress = 0.0
		if _shaking:
			stop_shake()

	for child in _icons.get_children():
		child.queue_free()
	for ing in cup.layers:
		var slot := ArtSlot.new()
		slot.custom_minimum_size = ICON_SIZE
		slot.placeholder_font_size = 14
		slot.placeholder_corner_radius = 8
		slot.placeholder_border_width = 3
		slot.set_art(Art.ingredient(ing.id), ing.color, ing.display_name)
		slot.tooltip_text = ing.display_name
		_icons.add_child(slot)

	_cost.text = "Cup cost: $%d   |   5 stars pays $%d" % [cup.cost, max_payout]
	_shake_bar.visible = cup.has_drink() and not cup.shaken
	if not _shaking:
		_shake_bar.value = _shake_progress / SHAKE_TIME * 100.0

	$Slot.visible = not cup.present
	if not cup.present:
		_hint.text = "Grab a cup from the stack!  [C]"
	elif not cup.has_drink():
		_hint.text = "Add ingredients from the bar"
	elif not cup.shaken:
		_hint.text = "Hold SHAKE to mix it  [S]"
	else:
		_hint.text = "Mixed! Serve it  [Space]"
	_hint.visible = true

	_shake_button.disabled = not (active and cup.present and cup.has_drink() and not cup.shaken)
	_serve_button.disabled = not can_serve()
	_trash_button.disabled = not (active and cup.present and not cup.is_empty())
