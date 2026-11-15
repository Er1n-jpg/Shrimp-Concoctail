class_name Cup
extends Control
## The drink being made. Liquid layers are drawn BEHIND the cup art
## (res://assets/ui/cup.png), so give the cup image a see-through body.

signal changed

## Shown under the cup so the player can see what a perfect drink pays.
var max_payout: int = 0:
	set(value):
		max_payout = value
		_update_label()

## Ingredients in pour order (bottom to top).
var layers: Array[IngredientData] = []
## Money spent on this cup so far.
var cost: int = 0
## Pours that are paid for but still brewing.
var pending: int = 0

@onready var _liquid: Control = $Liquid
@onready var _cost_label: Label = $CostLabel


func _ready() -> void:
	_liquid.draw.connect(_draw_liquid)
	_update_label()


func has_drink() -> bool:
	return not layers.is_empty()


func is_empty() -> bool:
	return layers.is_empty() and pending == 0


func space_left() -> int:
	return GameState.CUP_CAPACITY - layers.size() - pending


## Records a paid pour. Brewing pours hold a slot until they land.
func reserve(price: int, brewing: bool) -> void:
	cost += price
	if brewing:
		pending += 1
	_changed()


func add(ingredient: IngredientData, was_brewing: bool) -> void:
	if was_brewing:
		pending = maxi(pending - 1, 0)
	layers.append(ingredient)
	_changed()


## { ingredient_id: pour_count }
func contents() -> Dictionary:
	var result := {}
	for ing in layers:
		result[ing.id] = int(result.get(ing.id, 0)) + 1
	return result


func clear() -> void:
	layers.clear()
	cost = 0
	pending = 0
	_changed()


func _changed() -> void:
	_liquid.queue_redraw()
	_update_label()
	changed.emit()


func _update_label() -> void:
	if not is_node_ready():
		return
	_cost_label.text = "Cup cost: $%d   |   5 stars pays $%d" % [cost, max_payout]


func _draw_liquid() -> void:
	var area := _liquid.size
	var band := area.y / GameState.CUP_CAPACITY
	var font := get_theme_default_font()
	var font_size := 24
	var slot := 0
	for ing in layers:
		var rect := Rect2(0.0, area.y - band * (slot + 1), area.x, band)
		_liquid.draw_rect(rect, ing.color)
		_liquid.draw_rect(rect, Color(Palette.INK, 0.35), false, 2.0)
		var text_color := Palette.TEXT_DARK if ing.color.get_luminance() > 0.55 else Palette.TEXT_LIGHT
		var baseline := rect.position.y + band * 0.5 + font_size * 0.35
		_liquid.draw_string(font, Vector2(0.0, baseline), ing.display_name, HORIZONTAL_ALIGNMENT_CENTER, area.x, font_size, text_color)
		slot += 1
	for i in pending:
		var rect := Rect2(0.0, area.y - band * (slot + 1), area.x, band)
		_liquid.draw_rect(rect, Color(Palette.CREAM, 0.15))
		var baseline := rect.position.y + band * 0.5 + font_size * 0.35
		_liquid.draw_string(font, Vector2(0.0, baseline), "brewing...", HORIZONTAL_ALIGNMENT_CENTER, area.x, font_size, Color(Palette.CREAM, 0.7))
		slot += 1
