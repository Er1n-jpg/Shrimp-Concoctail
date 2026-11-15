extends Control
## Runs the bar. For each customer:
##   TALK   - the customer and the shrimp chat (no bar on screen)
##   BAR    - the camera pans down to the scrollable bar: grab a cup, pick ingredients,
##            hold Shake to mix, Serve. Patience only runs here.
##   REVIEW - the camera pans back up, the customer reacts and leaves a review.
##
## Keys: Space/Enter = next line / serve / skip review, Tab = skip the talk,
## C = grab a cup, S (hold) = shake, X/Backspace = trash, Q = ask (Vibecoder),
## A/D or arrow keys = move along the bar.

enum Phase { ARRIVING, TALKING, TO_BAR, BAR, TO_TALK, REVIEW, LEAVING, OVER }

const SCREEN := Vector2(1920, 1080)
const BAR_Y := 1080.0
const BAR_WIDTH := 3840.0
const PAN_TIME := 0.6
const SCROLL_SPEED := 1800.0
const EDGE_SCROLL_SPEED := 1100.0
const EDGE_ZONE := 40.0
const WHEEL_STEP := 160.0
const REVIEW_MIN_TIME := 1.3
const REVIEW_MAX_TIME := 3.5
const REVIEW_TIME_PER_CHAR := 0.025
const SHRIMP_NAME := "Shrimp"
const ICE_LABEL_OFF := "Ice (free)"
const ICE_LABEL_ON := "Ice: ON"

var _phase := Phase.ARRIVING
var _customer_data: CustomerData
var _required: PackedStringArray = []
var _revealed := 0
## [{ "shrimp": bool, "text": String }]
var _lines: Array[Dictionary] = []
var _line_index := 0
var _scroll_x := 0.0
var _dragging := false
var _review_timer: SceneTreeTimer
var _last_customer_id := ""
## customer id -> GameState.served when they last showed up (for cooldowns)
var _last_seen: Dictionary = {}
var _toast_tween: Tween
var _greyscale_tween: Tween
var _camera_tween: Tween
var _bar_ui_tween: Tween

@onready var _camera: Camera2D = $Camera
@onready var _customer: CustomerView = $World/TalkView/Customer
@onready var _bubble: SpeechBubble = $World/TalkView/CustomerBubble
@onready var _shrimp_box: SpeechBubble = $World/TalkView/ShrimpBox
@onready var _review: ReviewPopup = $World/TalkView/ReviewPopup
@onready var _talk_hint: Label = $World/TalkView/TalkHint
@onready var _cup_stack: PickupButton = $World/BarView/CupStack
@onready var _ice_chest: PickupButton = $World/BarView/IceChest
@onready var _fx_world: Control = $World/FxWorld
@onready var _bar_ui: Control = $UI/BarUI
@onready var _ticket: OrderTicket = $UI/BarUI/Ticket
@onready var _tray: CupTray = $UI/BarUI/CupTray
@onready var _scroller: BarScroller = $UI/BarUI/Scroller
@onready var _toast: Label = $UI/Toast
@onready var _fx_ui: Control = $UI/FxUI
@onready var _greyscale: ColorRect = $GreyscaleLayer/Greyscale
@onready var _game_over_screen: GameOverScreen = $GameOverLayer/GameOver


func _ready() -> void:
	GameState.reset()
	for node in get_tree().get_nodes_in_group("dispensers"):
		var dispenser := node as Dispenser
		dispenser.pour_requested.connect(_on_pour_requested)
		dispenser.poured.connect(_on_poured)
	_cup_stack.pressed.connect(_grab_cup)
	_ice_chest.pressed.connect(_toggle_ice)
	_tray.serve_pressed.connect(_serve)
	_tray.trash_pressed.connect(_trash)
	_tray.blocked.connect(_show_toast)
	_tray.shake_finished.connect(func() -> void:
		_float_text(_fx_ui, "Mixed!", _tray_cup_center() + Vector2(0, -110), Palette.BUTTER))
	_ticket.patience_ran_out.connect(_on_patience_ran_out)
	_ticket.ask_pressed.connect(_ask)
	_review.skip_requested.connect(_skip_review)
	_scroller.scrolled.connect(func(ratio: float) -> void: _scroll_x = ratio * _max_scroll())
	GameState.inflation_changed.connect(_on_inflation_changed)
	_game_over_screen.retry_pressed.connect(func() -> void: get_tree().reload_current_scene())

	_camera.position = Vector2.ZERO
	_camera.make_current()
	_scroller.page = SCREEN.x / BAR_WIDTH
	_bar_ui.visible = false
	_bar_ui.modulate.a = 0.0
	_greyscale.visible = false
	_toast.modulate.a = 0.0
	_tray.reset()
	_next_customer()


# --- Input ---

func _input(event: InputEvent) -> void:
	# Mouse wheel scrolls the bar even when the pointer is over an ingredient.
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or _phase != Phase.BAR:
		return
	match wheel.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			_scroll_x -= WHEEL_STEP
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			_scroll_x += WHEEL_STEP


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			match _phase:
				Phase.TALKING:
					_advance_talk()
				Phase.REVIEW:
					_skip_review()
				Phase.BAR:
					_dragging = true
		else:
			_dragging = false
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		if _dragging and _phase == Phase.BAR:
			_scroll_x -= motion.relative.x
		return

	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if key.keycode == KEY_S:
		if key.pressed:
			_tray.start_shake()
		else:
			_tray.stop_shake()
		return
	if not key.pressed:
		return
	match key.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			match _phase:
				Phase.TALKING:
					_advance_talk()
				Phase.BAR:
					_tray.try_serve()
				Phase.REVIEW:
					_skip_review()
		KEY_TAB:
			if _phase == Phase.TALKING:
				_go_to_bar()
		KEY_C:
			_grab_cup()
		KEY_X, KEY_BACKSPACE:
			_trash()
		KEY_Q:
			_ask()


func _process(delta: float) -> void:
	if _phase != Phase.BAR:
		return
	var direction := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
	_scroll_x += direction * SCROLL_SPEED * delta

	# Nudge along when the mouse rests at the left/right edge (above the cup tray).
	var mouse := get_viewport().get_mouse_position()
	if not _dragging and get_window().has_focus() and mouse.y > 70.0 and mouse.y < 620.0:
		if mouse.x < EDGE_ZONE:
			_scroll_x -= EDGE_SCROLL_SPEED * delta
		elif mouse.x > SCREEN.x - EDGE_ZONE:
			_scroll_x += EDGE_SCROLL_SPEED * delta

	_scroll_x = clampf(_scroll_x, 0.0, _max_scroll())
	_camera.position = Vector2(_scroll_x, BAR_Y)
	_scroller.ratio = _scroll_x / _max_scroll()


func _max_scroll() -> float:
	return BAR_WIDTH - SCREEN.x


# --- Talk ---

func _next_customer() -> void:
	_phase = Phase.ARRIVING
	_customer_data = _pick_customer()
	_required = _roll_recipe(_customer_data)
	_revealed = 0
	_last_customer_id = _customer_data.id
	_last_seen[_customer_data.id] = GameState.served
	var convos := _customer_data.conversations
	_lines = _parse_conversation(convos[randi() % convos.size()] if not convos.is_empty() else "...")
	_tray.reset()
	_tray.max_payout = GameState.max_payout(_customer_data)
	_ice_chest.set_label(ICE_LABEL_OFF)
	_set_greyscale(_customer_data.greyscale)
	Sfx.play("customer_in")

	await _customer.arrive(_customer_data)
	if _phase != Phase.ARRIVING:
		return
	_phase = Phase.TALKING
	_talk_hint.visible = true
	_line_index = 0
	_show_line()


func _parse_conversation(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			continue
		if line.to_lower().begins_with("shrimp:"):
			out.append({"shrimp": true, "text": line.substr(7).strip_edges()})
		else:
			out.append({"shrimp": false, "text": line})
	if out.is_empty():
		out.append({"shrimp": false, "text": "..."})
	return out


func _show_line() -> void:
	var line := _lines[_line_index]
	if line.shrimp:
		_bubble.hide_bubble()
		_shrimp_box.show_line(SHRIMP_NAME, line.text)
		Sfx.play("talk_shrimp")
	else:
		_shrimp_box.hide_bubble()
		_bubble.show_line(_customer_data.display_name, line.text)
		Sfx.play("talk")


func _advance_talk() -> void:
	var box := _shrimp_box if _shrimp_box.visible else _bubble
	if box.is_typing():
		box.finish_typing()
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_go_to_bar()
	else:
		_show_line()


func _go_to_bar() -> void:
	if _phase != Phase.TALKING:
		return
	_phase = Phase.TO_BAR
	_bubble.hide_bubble()
	_shrimp_box.hide_bubble()
	_talk_hint.visible = false
	_ticket.show_order(_customer_data, _required, _revealed, _customer_data.hidden_recipe, GameState.patience())
	_scroll_x = 0.0
	_scroller.ratio = 0.0
	_set_bar_ui(true)
	Sfx.play("whoosh")
	await _pan_camera(Vector2(0.0, BAR_Y))
	if _phase != Phase.TO_BAR:
		return
	_phase = Phase.BAR
	_tray.active = true
	_ticket.start()


# --- Bar ---

func _grab_cup() -> void:
	if _phase != Phase.BAR or _tray.cup.present:
		return
	_tray.cup.present = true
	Sfx.play("cup")
	_fly(Art.load_texture(Art.ROOT + "cup/empty"), Palette.BLUSH, _to_screen(_cup_stack.art_center()), 128.0)


func _toggle_ice() -> void:
	if _phase != Phase.BAR:
		return
	if not _tray.cup.present:
		_show_toast("Grab a cup first!  [C]")
		return
	_tray.cup.set_ice(not _tray.cup.ice)
	_ice_chest.set_label(ICE_LABEL_ON if _tray.cup.ice else ICE_LABEL_OFF)
	Sfx.play("ice")


func _on_pour_requested(dispenser: Dispenser) -> void:
	if _phase != Phase.BAR or dispenser.is_brewing():
		return
	var cup := _tray.cup
	if not cup.present:
		dispenser.deny()
		_show_toast("Grab a cup first!  [C]")
		return
	if cup.space_left() <= 0:
		dispenser.deny()
		_show_toast("Cup's full!")
		return
	var price := dispenser.price()
	if not GameState.spend(price):
		dispenser.deny()
		_show_toast("Can't afford that!")
		return
	cup.reserve(price, dispenser.ingredient.brew_time > 0.0)
	Sfx.play("pour")
	_float_text(_fx_world, "-$%d" % price, dispenser.global_position + Vector2(dispenser.size.x / 2.0, 0.0), Palette.LOSS)
	var art := Art.load_texture(Art.ingredient(dispenser.ingredient.id))
	_fly(art, dispenser.ingredient.color, _to_screen(dispenser.global_position + Vector2(dispenser.size.x / 2.0, 64.0)), 72.0)
	dispenser.dispense()


func _on_poured(ingredient: IngredientData) -> void:
	_tray.cup.add(ingredient, ingredient.brew_time > 0.0)


func _trash() -> void:
	if _phase != Phase.BAR or not _tray.cup.present or _tray.cup.is_empty():
		return
	_cancel_brews()
	if _tray.cup.cost > 0:
		_float_text(_fx_ui, "Wasted $%d" % _tray.cup.cost, _tray_cup_center() + Vector2(0, -120), Palette.LOSS)
	_tray.cup.clear()
	_ice_chest.set_label(ICE_LABEL_OFF)
	Sfx.play("trash")
	# Nothing left to make a drink with: run's over.
	if GameState.is_broke():
		_end_run()


func _ask() -> void:
	if _phase != Phase.BAR or not _ticket.can_ask():
		return
	_revealed += 1
	_ticket.spend(GameState.ASK_PATIENCE_COST)
	_ticket.set_icons(_required, _revealed, true)
	Sfx.play("ask")
	_float_text(_fx_ui, "-%ds" % int(GameState.ASK_PATIENCE_COST), _ticket.global_position + Vector2(_ticket.size.x / 2.0, _ticket.size.y + 40.0), Palette.ORANGE)


func _serve() -> void:
	if _phase != Phase.BAR or not _tray.can_serve():
		return
	var stars := DrinkJudge.rate(_tray.cup.contents(), _customer_data, _required, _ticket.time_left_ratio())
	Sfx.play("serve")
	_resolve(stars, false)


func _on_patience_ran_out() -> void:
	if _phase == Phase.BAR:
		_resolve(1, true)


func _cancel_brews() -> void:
	for node in get_tree().get_nodes_in_group("dispensers"):
		(node as Dispenser).cancel_brew()


# --- Review ---

func _resolve(stars: int, timed_out: bool) -> void:
	_phase = Phase.TO_TALK
	_ticket.stop()
	_tray.stop_shake()
	_tray.active = false
	_dragging = false
	_cancel_brews()

	var cup_cost := _tray.cup.cost
	var result := GameState.record_customer(stars, _customer_data)
	var payout: int = result.payout
	_set_bar_ui(false)
	Sfx.play("whoosh")
	await _pan_camera(Vector2.ZERO)
	_tray.reset()

	_phase = Phase.REVIEW
	_customer.react(stars)
	var detail := "Too slow!  (cup cost $%d)" % cup_cost if timed_out else \
		"x%s rating   x%s streak   (cup cost $%d)" % [_fmt(result.star_mult), _fmt(result.streak_mult), cup_cost]
	var review_text := _customer_data.reviews[stars - 1] if _customer_data.reviews.size() >= stars else ""
	_review.show_review(_customer_data.display_name, stars, review_text, payout, detail)
	if payout > 0:
		Sfx.play("cash")
	if stars <= 1:
		Sfx.play("bad")
		_shake()

	var wait := clampf(REVIEW_MIN_TIME + review_text.length() * REVIEW_TIME_PER_CHAR, REVIEW_MIN_TIME, REVIEW_MAX_TIME)
	_review_timer = get_tree().create_timer(wait)
	await _review_timer.timeout
	_review_timer = null
	_review.hide_popup()
	_phase = Phase.LEAVING
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
	_phase = Phase.OVER
	_ticket.stop()
	_tray.active = false
	_set_bar_ui(false)
	_bubble.hide_bubble()
	_shrimp_box.hide_bubble()
	_set_greyscale(false)
	Sfx.play("game_over")
	_game_over_screen.show_result(GameState.served, GameState.best, GameState.new_best_this_run)


# --- Customers ---

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
	var ids := Database.recipe_ingredient_ids()
	ids.shuffle()
	var count := randi_range(customer.hidden_recipe_size.x, customer.hidden_recipe_size.y)
	return PackedStringArray(ids.slice(0, count))


# --- Camera, UI and juice ---

func _pan_camera(to: Vector2) -> void:
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "position", to, PAN_TIME)
	await _camera_tween.finished


func _set_bar_ui(on: bool) -> void:
	if _bar_ui_tween != null:
		_bar_ui_tween.kill()
	if on:
		_bar_ui.visible = true
	_bar_ui_tween = create_tween()
	_bar_ui_tween.tween_property(_bar_ui, "modulate:a", 1.0 if on else 0.0, 0.3)
	if not on:
		_bar_ui_tween.tween_callback(func() -> void: _bar_ui.visible = false)


func _on_inflation_changed(level: int) -> void:
	if level == 0:
		return
	Sfx.play("inflation")
	_show_toast("Sponsor pulled out! Prices up!")


func _set_greyscale(on: bool) -> void:
	# Cancel any fade still running, or a finishing fade-out could hide the
	# greyscale right after the next customer turned it on.
	if _greyscale_tween != null:
		_greyscale_tween.kill()
	var mat := _greyscale.material as ShaderMaterial
	if on:
		_greyscale.visible = true
	_greyscale_tween = create_tween()
	_greyscale_tween.tween_property(mat, "shader_parameter/amount", 1.0 if on else 0.0, 0.5)
	if not on:
		_greyscale_tween.tween_callback(func() -> void: _greyscale.visible = false)


func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.1)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


## World position -> screen position (for effects drawn on the fixed UI layer).
func _to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _tray_cup_center() -> Vector2:
	return _tray.cup.global_position + _tray.cup.size / 2.0


## A picked-up item flies from `from` (screen space) into the cup.
func _fly(texture: Texture2D, color: Color, from: Vector2, item_size: float) -> void:
	var item: Control
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item = rect
	else:
		var block := ColorRect.new()
		block.color = color
		item = block
	item.size = Vector2(item_size, item_size)
	item.pivot_offset = item.size / 2.0
	item.mouse_filter = MOUSE_FILTER_IGNORE
	_fx_ui.add_child(item)
	item.position = from - item.size / 2.0
	var target := _tray_cup_center() - item.size / 2.0
	var tween := item.create_tween().set_parallel()
	tween.tween_property(item, "position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(item, "scale", Vector2(0.5, 0.5), 0.35)
	tween.chain().tween_callback(item.queue_free)


func _float_text(parent: Control, text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.reset_size()
	label.global_position = at - Vector2(label.size.x / 2.0, label.size.y)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _shake() -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_property(_camera, "offset", Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)), 0.035)
	tween.tween_property(_camera, "offset", Vector2.ZERO, 0.05)


func _fmt(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
