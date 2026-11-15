extends Control
## The bar: spawns customers, handles pours, serving, reviews and the broke check.
## Controls: click ingredients to pour, Space/Enter = serve, X/Backspace = trash, Q = ask (Vibecoder).

const REVIEW_MIN_TIME := 1.3
const REVIEW_MAX_TIME := 3.5
const REVIEW_TIME_PER_CHAR := 0.025

var _customer_data: CustomerData
var _required: PackedStringArray = []
var _revealed := 0
var _accepting := false
var _game_over := false
var _review_timer: SceneTreeTimer
var _last_customer_id := ""
## customer id -> GameState.served when they last showed up (for cooldowns)
var _last_seen: Dictionary = {}
var _toast_tween: Tween

@onready var _world: Control = $World
@onready var _customer: CustomerView = $World/Customer
@onready var _bubble: OrderBubble = $World/OrderBubble
@onready var _review: ReviewPopup = $World/ReviewPopup
@onready var _cup: Cup = $World/Cup
@onready var _serve_button: Button = $World/ServeButton
@onready var _trash_button: Button = $World/TrashButton
@onready var _fx: Control = $Fx
@onready var _toast: Label = $Toast
@onready var _greyscale: ColorRect = $GreyscaleLayer/Greyscale
@onready var _game_over_screen: GameOverScreen = $GameOverLayer/GameOver


func _ready() -> void:
	GameState.reset()
	for node in get_tree().get_nodes_in_group("dispensers"):
		var dispenser := node as Dispenser
		dispenser.pour_requested.connect(_on_pour_requested)
		dispenser.poured.connect(_on_poured)
	_serve_button.focus_mode = FOCUS_NONE
	_trash_button.focus_mode = FOCUS_NONE
	_serve_button.pressed.connect(_serve)
	_trash_button.pressed.connect(_trash)
	_customer.patience_ran_out.connect(_on_patience_ran_out)
	_bubble.ask_pressed.connect(_ask)
	_review.skip_requested.connect(_skip_review)
	_cup.changed.connect(_update_buttons)
	GameState.inflation_changed.connect(_on_inflation_changed)
	_game_over_screen.retry_pressed.connect(func() -> void: get_tree().reload_current_scene())
	_greyscale.visible = false
	_toast.modulate.a = 0.0
	_update_buttons()
	_next_customer()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if _review_timer != null:
				_skip_review()
			else:
				_serve()
		KEY_X, KEY_BACKSPACE:
			_trash()
		KEY_Q:
			_ask()


# --- Customer flow ---

func _next_customer() -> void:
	_customer_data = _pick_customer()
	_required = _roll_recipe(_customer_data)
	_revealed = 0
	_last_customer_id = _customer_data.id
	_last_seen[_customer_data.id] = GameState.served
	_cup.max_payout = GameState.max_payout(_customer_data)
	_set_greyscale(_customer_data.greyscale)
	Sfx.play("customer_in")

	await _customer.arrive(_customer_data, GameState.patience())

	var lines := _customer_data.order_lines
	var line := lines[randi() % lines.size()] if not lines.is_empty() else "..."
	_bubble.show_order(line, _required, _revealed, _customer_data.hidden_recipe)
	_accepting = true
	_customer.start_waiting()
	_update_buttons()


func _pick_customer() -> CustomerData:
	var pool: Array[CustomerData] = []
	for c in Database.customers:
		if c.id == _last_customer_id:
			continue
		if c.cooldown > 0 and _last_seen.has(c.id) and GameState.served - int(_last_seen[c.id]) < c.cooldown:
			continue
		pool.append(c)
	if pool.is_empty():
		pool.append_array(Database.customers)

	var total := 0.0
	for c in pool:
		total += c.spawn_weight
	var roll := randf() * total
	for c in pool:
		roll -= c.spawn_weight
		if roll <= 0.0:
			return c
	return pool.back()


func _roll_recipe(customer: CustomerData) -> PackedStringArray:
	if not customer.hidden_recipe:
		return customer.required
	var ids: Array = Database.ingredients.keys()
	ids.shuffle()
	var count := randi_range(customer.hidden_recipe_size.x, customer.hidden_recipe_size.y)
	return PackedStringArray(ids.slice(0, count))


func _serve() -> void:
	if not _accepting or not _cup.has_drink():
		return
	_cancel_brews()
	var stars := DrinkJudge.rate(_cup.contents(), _customer_data, _required, _customer.time_left_ratio())
	Sfx.play("serve")
	_resolve(stars, false)


func _on_patience_ran_out() -> void:
	if not _accepting:
		return
	_cancel_brews()
	_resolve(1, true)


func _resolve(stars: int, timed_out: bool) -> void:
	_accepting = false
	_customer.stop_waiting()
	_bubble.hide_bubble()

	var cup_cost := _cup.cost
	var result := GameState.record_customer(stars, _customer_data)
	var payout: int = result.payout
	_cup.clear()
	_customer.react(stars)

	var detail := "Too slow!  (cup cost $%d)" % cup_cost if timed_out else \
		"x%s rating   x%s streak   (cup cost $%d)" % [_fmt(result.star_mult), _fmt(result.streak_mult), cup_cost]
	var review_text := _customer_data.reviews[stars - 1] if _customer_data.reviews.size() >= stars else ""
	_review.show_review(_customer_data.display_name, stars, review_text, payout, detail)

	if payout > 0:
		Sfx.play("cash")
		_float_text("+$%d" % payout, _cup.global_position + Vector2(_cup.size.x / 2.0, 0.0), Palette.GAIN)
	if stars <= 1:
		Sfx.play("bad")
		_shake()
	_update_buttons()

	var wait := clampf(REVIEW_MIN_TIME + review_text.length() * REVIEW_TIME_PER_CHAR, REVIEW_MIN_TIME, REVIEW_MAX_TIME)
	_review_timer = get_tree().create_timer(wait)
	await _review_timer.timeout
	_review_timer = null
	_review.hide_popup()
	_set_greyscale(false)
	await _customer.leave()

	if GameState.is_broke():
		_end_run()
		return
	_next_customer()


func _skip_review() -> void:
	if _review_timer != null:
		_review_timer.timeout.emit()


func _end_run() -> void:
	_game_over = true
	_accepting = false
	_customer.stop_waiting()
	_bubble.hide_bubble()
	_set_greyscale(false)
	_update_buttons()
	Sfx.play("game_over")
	_game_over_screen.show_result(GameState.served, GameState.best, GameState.new_best_this_run)


# --- Mixing ---

func _on_pour_requested(dispenser: Dispenser) -> void:
	if not _accepting or dispenser.is_brewing():
		return
	if _cup.space_left() <= 0:
		dispenser.deny()
		_show_toast("Cup's full!")
		return
	var price := dispenser.price()
	if not GameState.spend(price):
		dispenser.deny()
		_show_toast("Can't afford that!")
		return
	_cup.reserve(price, dispenser.ingredient.brew_time > 0.0)
	Sfx.play("pour")
	_float_text("-$%d" % price, dispenser.global_position + Vector2(dispenser.size.x / 2.0, 0.0), Palette.LOSS)
	dispenser.dispense()


func _on_poured(ingredient: IngredientData) -> void:
	_cup.add(ingredient, ingredient.brew_time > 0.0)


func _trash() -> void:
	if not _accepting or _cup.is_empty():
		return
	_cancel_brews()
	if _cup.cost > 0:
		_float_text("Wasted $%d" % _cup.cost, _cup.global_position + Vector2(_cup.size.x / 2.0, 0.0), Palette.LOSS)
	_cup.clear()
	Sfx.play("trash")
	# Nothing left to make a drink with: run's over.
	if GameState.is_broke():
		_end_run()


func _ask() -> void:
	if not _accepting or not _bubble.can_ask():
		return
	_revealed += 1
	_customer.spend_patience(GameState.ASK_PATIENCE_COST)
	_bubble.set_ticket(_required, _revealed, true)
	Sfx.play("ask")
	_float_text("-%ds" % int(GameState.ASK_PATIENCE_COST), _customer.global_position + Vector2(_customer.size.x / 2.0, 40.0), Palette.ORANGE)


func _cancel_brews() -> void:
	for node in get_tree().get_nodes_in_group("dispensers"):
		(node as Dispenser).cancel_brew()


func _update_buttons() -> void:
	_serve_button.disabled = not (_accepting and _cup.has_drink())
	_trash_button.disabled = not (_accepting and not _cup.is_empty())


# --- Juice ---

func _on_inflation_changed(level: int) -> void:
	if level == 0:
		return
	Sfx.play("inflation")
	_show_toast("Sponsor pulled out! Prices up!")


func _set_greyscale(on: bool) -> void:
	var mat := _greyscale.material as ShaderMaterial
	if on:
		_greyscale.visible = true
	var tween := create_tween()
	tween.tween_property(mat, "shader_parameter/amount", 1.0 if on else 0.0, 0.5)
	if not on:
		tween.tween_callback(func() -> void: _greyscale.visible = false)


func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.1)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _float_text(text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	_fx.add_child(label)
	label.reset_size()
	label.global_position = at - Vector2(label.size.x / 2.0, label.size.y)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _shake() -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_property(_world, "position", Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)), 0.035)
	tween.tween_property(_world, "position", Vector2.ZERO, 0.05)


func _fmt(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
