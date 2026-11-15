class_name CustomerView
extends Control
## The customer standing at the bar: portrait, name and patience bar.
## Art: res://assets/customers/<id>.png (+ optional <id>_happy.png / <id>_mad.png).

signal patience_ran_out

const ENTER_TIME := 0.35
const EXIT_TIME := 0.3

var data: CustomerData

var _home_x := 0.0
var _patience_total := 1.0
var _patience_left := 0.0
var _waiting := false
var _fill_style := StyleBoxFlat.new()

@onready var _portrait: ArtSlot = $Portrait
@onready var _name_label: Label = $NameLabel
@onready var _patience_bar: ProgressBar = $PatienceBar


func _ready() -> void:
	_home_x = position.x
	visible = false
	_fill_style.set_corner_radius_all(6)
	_patience_bar.add_theme_stylebox_override("fill", _fill_style)


## Slides the customer in. Await this.
func arrive(customer: CustomerData, patience: float) -> void:
	data = customer
	_portrait.set_art(Art.customer(customer.id), _color_for(customer.id), customer.display_name)
	_name_label.text = customer.display_name
	_patience_total = patience
	_patience_left = patience
	_update_bar()

	position.x = -size.x - 40.0
	visible = true
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", _home_x, ENTER_TIME)
	await tween.finished


## Slides the customer out. Await this.
func leave() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", -size.x - 40.0, EXIT_TIME)
	await tween.finished
	visible = false


func start_waiting() -> void:
	_waiting = true


func stop_waiting() -> void:
	_waiting = false


func time_left_ratio() -> float:
	return clampf(_patience_left / _patience_total, 0.0, 1.0)


func spend_patience(seconds: float) -> void:
	_patience_left -= seconds
	_update_bar()


## Swaps to the happy/mad art if those files exist, and does a little hop or shake.
func react(stars: int) -> void:
	var mood := ""
	if stars >= 4:
		mood = "happy"
	elif stars <= 2:
		mood = "mad"
	if mood != "" and Art.load_texture(Art.customer(data.id, mood)) != null:
		_portrait.art_path = Art.customer(data.id, mood)

	var tween := create_tween()
	if stars >= 4:
		tween.tween_property(_portrait, "position:y", _portrait.position.y - 24.0, 0.1)
		tween.tween_property(_portrait, "position:y", _portrait.position.y, 0.15)
	elif stars <= 2:
		var x := _portrait.position.x
		for offset in [-12.0, 12.0, -8.0, 8.0, 0.0]:
			tween.tween_property(_portrait, "position:x", x + offset, 0.04)


func _process(delta: float) -> void:
	if not _waiting:
		return
	_patience_left -= delta
	_update_bar()
	if _patience_left <= 0.0:
		_waiting = false
		patience_ran_out.emit()


func _update_bar() -> void:
	var ratio := time_left_ratio()
	_patience_bar.value = ratio * 100.0
	if ratio < 0.5:
		_fill_style.bg_color = Palette.RUST.lerp(Palette.ORANGE, ratio * 2.0)
	else:
		_fill_style.bg_color = Palette.ORANGE.lerp(Palette.LIME, (ratio - 0.5) * 2.0)


func _color_for(id: String) -> Color:
	return Palette.CUSTOMER_COLORS[absi(id.hash()) % Palette.CUSTOMER_COLORS.size()]
