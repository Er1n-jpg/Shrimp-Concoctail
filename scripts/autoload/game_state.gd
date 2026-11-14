extends Node
## Run state (money, streak, inflation) and every balance number in one place.

signal money_changed(money: int)
signal served_changed(served: int)
signal streak_changed(streak: int)
signal best_changed(best: int)
signal inflation_changed(level: int)

# --- Balance: tweak these ---
const STARTING_MONEY := 20
const BASE_DRINK_PRICE := 10
const CUP_CAPACITY := 6
## Payout multiplier by star rating. Index = stars (index 0 unused).
const STAR_MULTIPLIERS := [0.0, 0.0, 0.5, 1.0, 1.5, 2.5]
## Drinks at or above this rating build the streak; anything lower resets it.
const STREAK_MIN_STARS := 4
const STREAK_STEP := 0.25
## Every N customers: ingredients and drinks get pricier, patience gets shorter.
const CUSTOMERS_PER_INFLATION := 5
const INFLATION_INGREDIENT_STEP := 1
const INFLATION_DRINK_STEP := 1
const START_PATIENCE := 15.0
const PATIENCE_STEP := 1.0
const MIN_PATIENCE := 7.0
## Seconds of patience the Vibecoder loses each time you ask a clarifying question.
const ASK_PATIENCE_COST := 3.0

const SAVE_PATH := "user://save.cfg"

var money: int = STARTING_MONEY
var served: int = 0
var streak: int = 0
var best: int = 0
var inflation_level: int = 0
var new_best_this_run: bool = false


func _ready() -> void:
	best = _load_best()
	Art.apply_custom_font()


func reset() -> void:
	money = STARTING_MONEY
	served = 0
	streak = 0
	inflation_level = 0
	new_best_this_run = false
	money_changed.emit(money)
	served_changed.emit(served)
	streak_changed.emit(streak)
	best_changed.emit(best)
	inflation_changed.emit(inflation_level)


func ingredient_price(ingredient: IngredientData) -> int:
	return ingredient.price + inflation_level * INFLATION_INGREDIENT_STEP


func drink_price(customer: CustomerData) -> int:
	return roundi((BASE_DRINK_PRICE + inflation_level * INFLATION_DRINK_STEP) * customer.price_multiplier)


func max_payout(customer: CustomerData) -> int:
	var five_star: float = STAR_MULTIPLIERS[5]
	return roundi(drink_price(customer) * five_star * streak_multiplier())


func patience() -> float:
	return maxf(START_PATIENCE - inflation_level * PATIENCE_STEP, MIN_PATIENCE)


func cheapest_price() -> int:
	return Database.cheapest_base_price() + inflation_level * INFLATION_INGREDIENT_STEP


func is_broke() -> bool:
	return money < cheapest_price()


func streak_multiplier() -> float:
	return 1.0 + streak * STREAK_STEP


## Takes money for a pour. Returns false if you can't afford it.
func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true


## Pays for a finished customer and advances the run.
## Returns { payout, star_mult, streak_mult }.
func record_customer(stars: int, customer: CustomerData) -> Dictionary:
	var star_mult: float = STAR_MULTIPLIERS[clampi(stars, 1, 5)]
	var streak_mult := streak_multiplier()
	var payout := roundi(drink_price(customer) * star_mult * streak_mult)

	money += payout
	streak = streak + 1 if stars >= STREAK_MIN_STARS else 0
	served += 1
	if served > best:
		best = served
		new_best_this_run = true
		_save_best()
		best_changed.emit(best)

	money_changed.emit(money)
	streak_changed.emit(streak)
	served_changed.emit(served)
	if served % CUSTOMERS_PER_INFLATION == 0:
		inflation_level += 1
		inflation_changed.emit(inflation_level)

	return {"payout": payout, "star_mult": star_mult, "streak_mult": streak_mult}


func _load_best() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value("scores", "best", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "best", best)
	config.save(SAVE_PATH)
