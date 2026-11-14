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
## Seconds it takes to brew before it lands in the cup (0 = instant).
@export var brew_time: float = 0.0


func has_tag(tag: String) -> bool:
	return tags.has(tag)
