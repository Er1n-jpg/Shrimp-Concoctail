class_name Dispenser
extends Button
## One ingredient on the counter. Click it or drag it onto the cup to pour (Main
## handles the clicking/dragging). Ingredients that brew (brew_time > 0: Espresso,
## Matcha) can't go straight in: you drag the spoon into the coffee machine instead.
## Set `ingredient` in the inspector; art comes from res://assets/ingredients/<id>.png

signal pour_requested(dispenser: Dispenser)
## Emitted when the ingredient lands in the cup.
signal poured(ingredient: IngredientData)

const AFFORDABLE_COLOR := Palette.MONEY
const BROKE_COLOR := Palette.LOSS

@export var ingredient: IngredientData:
	set(value):
		ingredient = value
		_refresh()

var _built := false

@onready var _art: ArtSlot = $Art
@onready var _name_label: Label = $NameLabel
@onready var _price_label: Label = $PriceLabel


func _ready() -> void:
	add_to_group("dispensers")
	focus_mode = FOCUS_NONE
	_apply_styles()
	pressed.connect(func() -> void:
		if not needs_machine():
			pour_requested.emit(self))
	GameState.money_changed.connect(func(_money: int) -> void: _update_price())
	GameState.inflation_changed.connect(_on_inflation_changed)
	_built = true
	_refresh()


func price() -> int:
	return GameState.ingredient_price(ingredient)


## Brewed ingredients go through the coffee machine (drag the spoon in).
func needs_machine() -> bool:
	return ingredient != null and ingredient.brew_time > 0.0


## Called by Main once the pour is paid for.
func dispense() -> void:
	_bounce()
	poured.emit(ingredient)


## The spoon is off the counter (being dragged, or in the machine): fade the art.
func set_away(away: bool) -> void:
	_art.modulate.a = 0.25 if away else 1.0
	if not away:
		_bounce()


## Can't pour (broke or cup full): little shake.
func deny() -> void:
	Sfx.play("denied")
	var tween := create_tween()
	for offset in [-8.0, 8.0, -5.0, 5.0, 0.0]:
		tween.tween_property(_art, "position:x", _art_home_x() + offset, 0.035)


func _refresh() -> void:
	if not _built or ingredient == null:
		return
	_art.set_art(Art.ingredient(ingredient.id), ingredient.color, "")
	_art.placeholder_border_color = Palette.TAUPE
	_art.placeholder_shadow = 6
	_name_label.text = ingredient.display_name
	mouse_default_cursor_shape = CURSOR_DRAG if needs_machine() else CURSOR_POINTING_HAND
	tooltip_text = "%s (%s)" % [ingredient.display_name, ", ".join(ingredient.tags)]
	_update_price()


func _update_price() -> void:
	if not _built or ingredient == null:
		return
	var p := price()
	_price_label.text = "$%d" % p
	_price_label.add_theme_color_override("font_color", AFFORDABLE_COLOR if GameState.money >= p else BROKE_COLOR)


func _on_inflation_changed(level: int) -> void:
	_update_price()
	if level == 0:
		return
	# Flash the price tag red so the price hike is obvious.
	_price_label.pivot_offset = _price_label.size / 2.0
	var tween := create_tween()
	tween.tween_property(_price_label, "modulate", Palette.RUST, 0.12)
	tween.parallel().tween_property(_price_label, "scale", Vector2(1.35, 1.35), 0.12)
	tween.tween_property(_price_label, "modulate", Color.WHITE, 0.5)
	tween.parallel().tween_property(_price_label, "scale", Vector2.ONE, 0.5)


func _bounce() -> void:
	_art.pivot_offset = _art.size / 2.0
	var tween := create_tween()
	tween.tween_property(_art, "scale", Vector2(0.88, 0.88), 0.05)
	tween.tween_property(_art, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _art_home_x() -> float:
	return (size.x - _art.size.x) / 2.0


func _apply_styles() -> void:
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(Palette.BUTTER, 0.14)
	hover.set_corner_radius_all(14)
	var pressed_box := hover.duplicate() as StyleBoxFlat
	pressed_box.bg_color = Color(Palette.BUTTER, 0.24)
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_box)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
