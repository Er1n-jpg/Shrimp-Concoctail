class_name CustomerData
extends Resource
## One customer type.
## Art is picked up automatically from res://assets/customers/<id>.png
## (optional mood swaps: <id>_happy.png for 4-5 stars, <id>_mad.png for 1-2 stars).
## What they say lives in a plain text file: res://data/dialogue/<id>.txt
## (see data/dialogue/README.md).

enum Rule {
	NONE,
	## Every ingredient must have the "green" tag (-1 per ingredient that doesn't).
	GREEN_ONLY,
	## Extra alcohol pours beyond the required ones earn a bonus.
	MORE_ALCOHOL,
}

@export var id: String = ""
@export var display_name: String = ""
@export_group("Recipe")
## Ingredient ids that must be in the drink (3). Each visit's conversation hints
## at 2 of them; the hint lines are in data/dialogue/<id>.txt.
@export var required: PackedStringArray = PackedStringArray()
## Ingredient ids that give a small bonus.
@export var liked: PackedStringArray = PackedStringArray()
## Ingredient ids that cost a star.
@export var hated: PackedStringArray = PackedStringArray()
@export var rule: Rule = Rule.NONE
## Vibecoder: the recipe is random and hidden until you ask.
@export var hidden_recipe: bool = false
## Min/max number of ingredients in a hidden recipe.
@export var hidden_recipe_size: Vector2i = Vector2i(2, 3)

@export_group("Reviews")
## reviews[0] is the 1-star review ... reviews[4] is the 5-star review.
@export var reviews: PackedStringArray = PackedStringArray()

@export_group("Spawning")
## Higher = shows up more often.
@export var spawn_weight: float = 1.0
## Multiplies the base drink price (Hensen Juang pays double).
@export var price_multiplier: float = 1.0
## Customers that must be served before this one can come back (0 = just never twice in a row).
@export var cooldown: int = 0

@export_group("Effects")
## Turns the whole screen greyscale while they're at the bar.
@export var greyscale: bool = false
