class_name CustomerView
extends Control
## The customer in the talk view. Art: res://assets/customers/<id>.png
## (+ optional <id>_happy.png / <id>_mad.png, swapped in after the review).

const ENTER_TIME := 0.35
const EXIT_TIME := 0.3

var data: CustomerData

var _home_x := 0.0

@onready var _portrait: ArtSlot = $Portrait


func _ready() -> void:
	_home_x = position.x
	visible = false


## Slides the customer in. Await this.
func arrive(customer: CustomerData) -> void:
	data = customer
	_portrait.set_art(Art.customer(customer.id), _color_for(customer.id), customer.display_name)
	_portrait.position = Vector2.ZERO
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


## Swaps to the happy/mad art if those files exist, and does a little hop or shake.
func react(stars: int) -> void:
	var mood := ""
	if stars >= 4:
		mood = "happy"
	elif stars <= 2:
		mood = "mad"
	if mood != "" and Art.load_texture(Art.customer(data.id, mood)) != null:
		_portrait.art_path = Art.customer(data.id, mood)

	if stars == 3:
		return  # neutral: no hop or shake
	var tween := create_tween()
	if stars >= 4:
		tween.tween_property(_portrait, "position:y", -30.0, 0.1)
		tween.tween_property(_portrait, "position:y", 0.0, 0.15)
	else:
		for offset in [-14.0, 14.0, -9.0, 9.0, 0.0]:
			tween.tween_property(_portrait, "position:x", offset, 0.04)


func _color_for(id: String) -> Color:
	return Palette.CUSTOMER_COLORS[absi(id.hash()) % Palette.CUSTOMER_COLORS.size()]
