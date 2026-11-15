class_name Dispenser
extends Button
## One ingredient on the counter. Click to pour.
## Set `ingredient` in the inspector; art comes from res://assets/ingredients/<id>.png

signal pour_requested(dispenser: Dispenser)
## Emitted when the ingredient actually lands in the cup (after brewing, if it brews).
signal poured(ingredient: IngredientData)

const AFFORDABLE_COLOR := Palette.MONEY
const BROKE_COLOR := Palette.LOSS

@export var ingredient: IngredientData:
	set(value):
		ingredient = value
		_refresh()

var _built := false
var _brewing := false
var _brew_tween: Tween

@onready var _art: ArtSlot = $Art
@onready var _name_label: Label = $NameLabel
@onready var _price_label: Label = $PriceLabel
@onready var _brew_bar: ProgressBar = $BrewBar


func _ready() -> void:
	add_to_group("dispensers")
	focus_mode = FOCUS_NONE
	_apply_styles()
	pressed.connect(func() -> void: pour_requested.emit(self))
	GameState.money_changed.connect(func(_money: int) -> void: _update_price())
	GameState.inflation_changed.connect(_on_inflation_changed)
	_brew_bar.visible = false
	_built = true
	_refresh()


func price() -> int:
	return GameState.ingredient_price(ingredient)


func is_brewing() -> bool:
	return _brewing


## Called by Main once the pour is paid for.
func dispense() -> void:
	_bounce()
	if ingredient.brew_time <= 0.0:
		poured.emit(ingredient)
		return
	_brewing = true
	_brew_bar.value = 0.0
	_brew_bar.visible = true
	_brew_tween = create_tween()
	_brew_tween.tween_property(_brew_bar, "value", 100.0, ingredient.brew_time)
	_brew_tween.tween_callback(_finish_brew)


func cancel_brew() -> void:
	if _brew_tween != null:
		_brew_tween.kill()
	_brewing = false
	_brew_bar.visible = false


## Can't pour (broke or cup full): little shake.
func deny() -> void:
	Sfx.play("denied")
	var tween := create_tween()
	for offset in [-8.0, 8.0, -5.0, 5.0, 0.0]:
		tween.tween_property(_art, "position:x", _art_home_x() + offset, 0.035)


func _finish_brew() -> void:
	_brewing = false
	_brew_bar.visible = false
	Sfx.play("brew_done")
	poured.emit(ingredient)


func _refresh() -> void:
	if not _built or ingredient == null:
		return
	_art.set_art(Art.ingredient(ingredient.id), ingredient.color, "")
	_art.placeholder_border_color = Palette.TAUPE
	_art.placeholder_shadow = 6
	_name_label.text = ingredient.display_name
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
