extends Node
## Loads every ingredient and customer resource at startup.
## To add one, drop a new .tres into res://data/ingredients/ or res://data/customers/.

const INGREDIENT_DIR := "res://data/ingredients/"
const CUSTOMER_DIR := "res://data/customers/"

## id -> IngredientData
var ingredients: Dictionary = {}
var customers: Array[CustomerData] = []


func _ready() -> void:
	for res in _load_dir(INGREDIENT_DIR):
		if res is IngredientData:
			ingredients[res.id] = res
	for res in _load_dir(CUSTOMER_DIR):
		if res is CustomerData:
			customers.append(res)
	_check_data()


func ingredient(id: String) -> IngredientData:
	return ingredients.get(id)


## Ingredient ids that can appear in a random (Vibecoder) recipe: no distractors.
func recipe_ingredient_ids() -> Array:
	var ids := []
	for ing: IngredientData in ingredients.values():
		if not ing.has_tag("distractor"):
			ids.append(ing.id)
	return ids


func cheapest_base_price() -> int:
	var cheapest := 999999
	for ing: IngredientData in ingredients.values():
		cheapest = mini(cheapest, ing.price)
	return cheapest


func _load_dir(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var files := ResourceLoader.list_directory(dir)
	files.sort()
	for file in files:
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(dir + file)
			if res != null:
				out.append(res)
	return out


func _check_data() -> void:
	for c in customers:
		for list: PackedStringArray in [c.required, c.liked, c.hated]:
			for id in list:
				if not ingredients.has(id):
					push_warning("Customer '%s' uses unknown ingredient '%s'" % [c.id, id])
		if c.reviews.size() != 5:
			push_warning("Customer '%s' should have exactly 5 reviews (has %d)" % [c.id, c.reviews.size()])
		if c.conversations.is_empty():
			push_warning("Customer '%s' has no conversations" % c.id)
