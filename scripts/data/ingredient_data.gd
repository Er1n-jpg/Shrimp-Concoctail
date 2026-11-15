class_name IngredientData
extends Resource
## One ingredient on the counter.
## Art is picked up automatically from res://assets/ingredients/<id>.png

@export var id: String = ""
@export var display_name: String = ""
## Starting price in dollars. Inflation adds to this as the run goes on.
@export var price: int = 1
## Liquid color in the cup, and the placeholder color until art exists.
@export var color: Color = Color.WHITE
## Used by customer rules: green, alcohol, caffeine, dairy, sweet, salty, spicy.
@export var tags: PackedStringArray = []
## Above 0 = it has to be dragged into the coffee machine, which takes this many
## seconds to brew it before it lands in the cup (0 = click to pour, instant).
@export var brew_time: float = 0.0


func has_tag(tag: String) -> bool:
	return tags.has(tag)
