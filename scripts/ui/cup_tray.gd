class_name CupTray
extends Control
## Full-screen bar workstation overlay: the big cup held in the bottom-left
## corner, the hover-only "Hold to shake" prompt, the ingredient icons, cost
## and action buttons.
##
## The cup stays at the same screen position while the counter scrolls, so it
## reads as being held close to the camera. Press the cup and move the mouse to
## shake it; the Shake button and S key still work too.

signal serve_pressed
signal trash_pressed
signal shake_finished
## Tried to shake/serve when that isn't possible yet. Carries a hint for a toast.
signal blocked(reason: String)

const SHAKE_TIME := 1.0
const ICON_SIZE := Vector2(48, 48)
## How far the mouse has to wiggle (in pixels) for one full shake.
const WIGGLE_DISTANCE := 430.0

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
var _auto_shake := true
var _shake_progress := 0.0
var _last_pour_count := 0
var _holding := false
var _last_mouse := Vector2.ZERO
var _cup_hover := false
var _drop_hover := false
var _cup_drag_hover := false
var _station_tween: Tween
var _slide_targets: Array[Control] = []
var _slide_home_x: Array[float] = []

@onready var cup: Cup = $Cup
@onready var _shadow: SoftShadow = $Shadow
@onready var _cup_prompt: Panel = $CupPrompt
@onready var _cup_prompt_label: Label = $CupPrompt/CupPromptLabel
@onready var _prompt_panel: Panel = $PromptPanel
@onready var _status: Label = $StatusLabel
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
	_cup_prompt.pivot_offset = _cup_prompt.size / 2.0
	# Resting screen positions, so an interrupted station slide can't drift.
	_slide_targets = [cup, _shadow, _prompt_panel, _shake_bar]
	for target in _slide_targets:
		_slide_home_x.append(target.position.x)
	_refresh()


## Fresh, cup-less tray for a new customer.
func reset() -> void:
	stop_shake()
	_shake_progress = 0.0
	_holding = false
	_cup_hover = false
	_drop_hover = false
	_cup_drag_hover = false
	_cup_prompt.scale = Vector2.ONE
	_cup_prompt_label.text = "drag a cup here"
	cup.set_drop_highlight(false)
	cup.clear()
	cup.present = false
	_refresh()


func can_serve() -> bool:
	return active and cup.present and cup.has_drink() and cup.shaken


func try_serve() -> void:
	if not active:
		return
	if not cup.present:
		blocked.emit("Drag a cup down first!")
	elif not cup.has_drink():
		blocked.emit("The cup's empty!")
	elif not cup.shaken:
		blocked.emit("Hold to shake it first!")
	else:
		serve_pressed.emit()


func start_shake() -> void:
	_begin_shake(true)


func stop_shake() -> void:
	if _shaking:
		cup.stop_shake()
	_shaking = false
	_auto_shake = false
	_refresh_hint()


## Called while an ingredient is being dragged over the cup.
func set_drop_hover(on: bool) -> void:
	if _drop_hover == on:
		return
	_drop_hover = on
	cup.set_drop_highlight(on)
	_refresh_hint()


## Called while a cup is being dragged out of the stack. Lights up the empty slot.
func set_cup_drag_hover(on: bool) -> void:
	on = on and not cup.present
	if _cup_drag_hover == on:
		return
	_cup_drag_hover = on
	_cup_prompt_label.text = "drop it!" if on else "drag a cup here"
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_cup_prompt, "scale", Vector2(1.05, 1.05) if on else Vector2.ONE, 0.12)
	_refresh_hint()


## A little lean/slide of the held cup when the counter moves to another station.
func play_station_slide(direction: int) -> void:
	if direction == 0:
		return
	if _station_tween != null:
		_station_tween.kill()
	var nudge := float(direction) * -26.0
	_station_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _slide_targets.size():
		_station_tween.tween_property(_slide_targets[i], "position:x", _slide_home_x[i] + nudge, 0.16)
	_station_tween.chain()
	for i in _slide_targets.size():
		_station_tween.tween_property(_slide_targets[i], "position:x", _slide_home_x[i], 0.38)


# --- Input: hold the cup and wiggle it ---

func _input(event: InputEvent) -> void:
	if not active:
		return
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			# The empty slot is just a label, so only the real cup starts a shake.
			if cup.present and cup.get_global_rect().has_point(click.position):
				_holding = true
				_last_mouse = click.position
				# Vibrate as soon as the cup is held; wiggling then fills the bar.
				if cup.has_drink() and not cup.shaken:
					_begin_shake(false)
				get_viewport().set_input_as_handled()
		elif _holding:
			_holding = false
			if _shaking:
				stop_shake()
			get_viewport().set_input_as_handled()
		return

	var motion := event as InputEventMouseMotion
	if motion != null and _holding:
		var dx := motion.position.x - _last_mouse.x
		_last_mouse = motion.position
		if absf(dx) > 0.35 and cup.present and cup.has_drink() and not cup.shaken:
			_wiggle(absf(dx))
		get_viewport().set_input_as_handled()


func _wiggle(amount: float) -> void:
	if not _shaking:
		_begin_shake(false)
	if not _shaking:
		return
	_shake_progress = minf(_shake_progress + amount / WIGGLE_DISTANCE, 1.0)
	_update_shake_ui()
	if _shake_progress >= 1.0:
		_finish_shake()


func _begin_shake(auto_progress: bool) -> void:
	if not active or _shaking:
		if _shaking:
			_auto_shake = auto_progress
		return
	if not cup.present:
		blocked.emit("Drag a cup down first!")
		return
	if not cup.has_drink():
		blocked.emit("Add something to shake!")
		return
	if cup.shaken:
		return
	_shaking = true
	_auto_shake = auto_progress
	Sfx.play("shake")
	_refresh_hint()


func _process(delta: float) -> void:
	_update_cup_hover()
	if not _shaking:
		return
	if _auto_shake:
		_shake_progress = minf(_shake_progress + delta / SHAKE_TIME, 1.0)
		_update_shake_ui()
		if _shake_progress >= 1.0:
			_finish_shake()
			return
	cup.shake_step(delta, _shake_progress)


func _update_cup_hover() -> void:
	var over := active and cup.present \
		and cup.get_global_rect().has_point(get_viewport().get_mouse_position())
	if over == _cup_hover:
		return
	_cup_hover = over
	_refresh_prompt()


func _finish_shake() -> void:
	_shaking = false
	_auto_shake = false
	_shake_progress = 0.0
	cup.finish_shake()
	Sfx.play("shake_done")
	shake_finished.emit()
	_refresh()


func _update_shake_ui() -> void:
	_refresh_hint()


func _refresh() -> void:
	if not is_node_ready():
		return
	# Adding an ingredient after (or during) shaking means shaking again from scratch.
	if cup.layers.size() != _last_pour_count:
		_last_pour_count = cup.layers.size()
		_shake_progress = 0.0
		if _shaking:
			stop_shake()

	_shadow.visible = cup.present
	_cup_prompt.visible = not cup.present
	if cup.present and _cup_drag_hover:
		_cup_drag_hover = false
		_cup_prompt.scale = Vector2.ONE
		_cup_prompt_label.text = "drag a cup here"

	for child in _icons.get_children():
		child.queue_free()
	for ing in cup.layers:
		var slot := ArtSlot.new()
		slot.custom_minimum_size = ICON_SIZE
		slot.placeholder_font_size = 12
		slot.placeholder_corner_radius = 8
		slot.placeholder_border_width = 2
		slot.set_art(Art.ingredient(ing.id), ing.color, ing.display_name)
		slot.tooltip_text = ing.display_name
		_icons.add_child(slot)

	_cost.text = "Cup cost: $%d   ·   5 stars pays $%d" % [cup.cost, max_payout]

	_shake_button.disabled = not (active and cup.present and cup.has_drink() and not cup.shaken)
	_serve_button.disabled = not can_serve()
	_trash_button.disabled = not (active and cup.present and not cup.is_empty())
	_refresh_hint()


func _refresh_hint() -> void:
	if not is_node_ready():
		return
	if _cup_drag_hover:
		_status.text = "drop the cup here!"
	elif _drop_hover:
		_status.text = "drop it in!"
	elif not cup.present:
		_status.text = "drag a cup down from the stack"
	elif not cup.has_drink():
		_status.text = "drag ingredients into the cup"
	elif not cup.shaken:
		_status.text = "keep wiggling!" if _shaking else "hold the cup and wiggle"
	else:
		_status.text = "shaken — serve it!"
	if not cup.present:
		_hint.text = "Drag a cup from the stack down here  ·  ← → / A D change station"
	else:
		_hint.text = "Drag ingredients onto the cup  ·  ← → / A D change station  ·  Space serves"
	_hint.visible = true
	_shake_bar.visible = active and cup.present and cup.has_drink() and not cup.shaken
	_shake_bar.value = _shake_progress * 100.0
	_refresh_prompt()


func _refresh_prompt() -> void:
	if not is_node_ready():
		return
	# The "Hold to shake" prompt is only ever shown while the mouse is over the cup.
	_prompt_panel.visible = active and cup.present and _cup_hover and not cup.shaken
