extends Control
## Runs the bar. For each customer:
##   TALK   - the customer and the shrimp chat (no bar on screen)
##   BAR    - the camera pans down to the scrollable bar: drag a cup out of the
##            stack, pick ingredients, hold Shake to mix, Serve. Patience only runs here.
##   REVIEW - the camera pans back up, the customer reacts and leaves a review.
##
## Keys: Space/Enter = next line / serve / skip review, Tab = skip the talk,
## S (hold) = shake, X/Backspace = trash, Q = ask (Vibecoder),
## A/D or arrow keys = move along the bar.
## Espresso and Matcha: drag the spoon into the coffee machine to brew a shot.

enum Phase { ARRIVING, TALKING, TO_BAR, BAR, TO_TALK, REVIEW, LEAVING, OVER }

const SCREEN := Vector2(1920, 1080)
const BAR_Y := 1080.0
const BAR_WIDTH := 7680.0
const STATION_STEP := 1920.0
const STATION_NAMES := ["CUPS", "COLD CANS", "BREW & CREAM", "JARS & SAUCES"]
const STATION_SUBTITLES := [
	"drag a cup · cups only",
	"energy drinks · soda · cold cans",
	"coffee machine · milk · ice cream",
	"sugar · spice · pickle juice",
]
const PAN_TIME := 0.6
const STATION_TIME := 0.55
const DRAG_THRESHOLD := 14.0
const REVIEW_MIN_TIME := 1.3
const REVIEW_MAX_TIME := 3.5
const REVIEW_TIME_PER_CHAR := 0.025
const SHRIMP_NAME := "Shrimp"

var _phase := Phase.ARRIVING
var _customer_data: CustomerData
var _required: PackedStringArray = []
var _revealed := 0
## [{ "shrimp": bool, "text": String }]
var _lines: Array[Dictionary] = []
var _line_index := 0
## The customer's side of the conversation, shown on the ticket at the bar.
var _what_they_said := ""
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
var _scroll_tween: Tween
var _station_title_tween: Tween
var _station_index := 0
## A dispenser the mouse went down on, before it counts as a drag or a click.
var _item_drag: Dispenser
var _item_drag_origin := Vector2.ZERO
var _item_dragging := false
var _drag_ghost: TextureRect
## Dragging a cup out of the stack on the cups station.
var _cup_pending := false
var _cup_drag_origin := Vector2.ZERO
var _cup_dragging := false
var _cup_ghost: TextureRect

@onready var _camera: Camera2D = $Camera
@onready var _customer: CustomerView = $World/TalkView/Customer
@onready var _bubble: SpeechBubble = $World/TalkView/CustomerBubble
@onready var _shrimp_box: SpeechBubble = $World/TalkView/ShrimpBox
@onready var _review: ReviewPopup = $World/TalkView/ReviewPopup
@onready var _talk_hint: Label = $World/TalkView/TalkHint
@onready var _cup_stack: PickupButton = $World/BarView/CupStack
@onready var _machine: CoffeeMachine = $World/BarView/CoffeeMachine
@onready var _fx_world: Control = $World/FxWorld
@onready var _bar_ui: Control = $UI/BarUI
@onready var _ticket: OrderTicket = $UI/BarUI/Ticket
@onready var _tray: CupTray = $UI/BarUI/CupTray
@onready var _scroller: BarScroller = $UI/BarUI/Scroller
@onready var _arrow_left: StationArrow = $UI/BarUI/ArrowLeft
@onready var _arrow_right: StationArrow = $UI/BarUI/ArrowRight
@onready var _station_title: Label = $UI/BarUI/StationTitle
@onready var _station_subtitle: Label = $UI/BarUI/StationSubtitle
@onready var _station_dots: StationProgress = $UI/BarUI/StationDots
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
	_cup_stack.pressed.connect(_on_cup_stack_pressed)
	_machine.brewed.connect(_on_brewed)
	_tray.serve_pressed.connect(_serve)
	_tray.trash_pressed.connect(_trash)
	_tray.blocked.connect(_show_toast)
	_tray.shake_finished.connect(func() -> void:
		_float_text(_fx_ui, "Mixed!", _tray_cup_center() + Vector2(0, -110), Palette.BUTTER))
	_ticket.patience_ran_out.connect(_on_patience_ran_out)
	_ticket.ask_pressed.connect(_ask)
	_review.skip_requested.connect(_skip_review)
	_scroller.scrolled.connect(_on_scroller_scrolled)
	_arrow_left.pressed.connect(func() -> void: _change_station(-1))
	_arrow_right.pressed.connect(func() -> void: _change_station(1))
	GameState.inflation_changed.connect(_on_inflation_changed)
	_game_over_screen.retry_pressed.connect(func() -> void: get_tree().reload_current_scene())

	_camera.position = Vector2.ZERO
	_camera.make_current()
	_scroller.page = SCREEN.x / BAR_WIDTH
	_bar_ui.visible = false
	_bar_ui.modulate.a = 0.0
	_greyscale.visible = false
	_toast.modulate.a = 0.0
	_station_index = 0
	_update_station_ui()
	_tray.reset()
	_next_customer()


# --- Input ---

func _input(event: InputEvent) -> void:
	if _phase != Phase.BAR:
		return

	# Mouse wheel jumps one station at a time, even over an ingredient.
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		match wheel.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				_change_station(-1)
				get_viewport().set_input_as_handled()
				return
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				_change_station(1)
				get_viewport().set_input_as_handled()
				return

	# Pressing an ingredient starts a click/drag. Releasing over the cup pours it;
	# releasing over the dispenser (a plain click) still pours it the old way.
	# The cup stack works the same way: press, drag a cup down, release on the slot.
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			# The station arrows sit above the counter. Let them win any click
			# that lands in their corner, even over an item's artwork.
			if _arrow_left.get_global_rect().has_point(click.position) \
					or _arrow_right.get_global_rect().has_point(click.position):
				return
			if _cup_stack_at(click.position) and not _tray.cup.present:
				_cup_pending = true
				_cup_drag_origin = click.position
				_cup_dragging = false
				get_viewport().set_input_as_handled()
				return
			var dispenser := _dispenser_at_screen(click.position)
			if dispenser != null:
				_begin_pending_drag(dispenser, click.position)
				get_viewport().set_input_as_handled()
		elif _cup_pending:
			_finish_cup_drag(click.position)
			get_viewport().set_input_as_handled()
		elif _item_drag != null:
			_finish_item_drag(click.position)
			get_viewport().set_input_as_handled()
		return

	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	if _cup_pending:
		if not _cup_dragging and motion.position.distance_to(_cup_drag_origin) >= DRAG_THRESHOLD:
			_start_cup_drag()
		if _cup_dragging:
			_move_cup_drag(motion.position)
		get_viewport().set_input_as_handled()
	elif _item_drag != null:
		if not _item_dragging and motion.position.distance_to(_item_drag_origin) >= DRAG_THRESHOLD:
			_start_item_drag()
		if _item_dragging:
			_move_item_drag(motion.position)
		get_viewport().set_input_as_handled()


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
			if _dragging and _phase == Phase.BAR:
				_snap_to_nearest_station()
			_dragging = false
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		if _dragging and _phase == Phase.BAR:
			_cancel_scroll_tween()
			_scroll_x = clampf(_scroll_x - motion.relative.x, 0.0, _max_scroll())
			_scroller.ratio = _scroll_x / _max_scroll()
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
	if _phase == Phase.BAR and (key.keycode == KEY_LEFT or key.keycode == KEY_A):
		_change_station(-1)
		return
	if _phase == Phase.BAR and (key.keycode == KEY_RIGHT or key.keycode == KEY_D):
		_change_station(1)
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
		KEY_X, KEY_BACKSPACE:
			_trash()
		KEY_Q:
			_ask()


func _process(_delta: float) -> void:
	if _phase != Phase.BAR:
		return
	_camera.position = Vector2(_scroll_x, BAR_Y)
	_scroller.ratio = _scroll_x / _max_scroll()


func _max_scroll() -> float:
	return BAR_WIDTH - SCREEN.x


# --- Counter stations ---

func _station_count() -> int:
	return STATION_NAMES.size()


func _change_station(direction: int) -> void:
	if _phase != Phase.BAR or direction == 0:
		return
	var target := clampi(_station_index + direction, 0, _station_count() - 1)
	if target == _station_index:
		return
	_station_index = target
	_animate_to_station(target, direction)


func _animate_to_station(index: int, direction: int) -> void:
	if _scroll_tween != null:
		_scroll_tween.kill()
	var target := float(index) * STATION_STEP
	_scroll_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_scroll_tween.tween_method(_set_scroll_x, _scroll_x, target, STATION_TIME)
	_tray.play_station_slide(direction)
	_update_station_ui()
	_pulse_station_title()
	Sfx.play("whoosh")


func _set_scroll_x(value: float) -> void:
	_scroll_x = clampf(value, 0.0, _max_scroll())
	_scroller.ratio = _scroll_x / _max_scroll()


func _cancel_scroll_tween() -> void:
	if _scroll_tween != null:
		_scroll_tween.kill()
		_scroll_tween = null


func _snap_to_nearest_station() -> void:
	_cancel_scroll_tween()
	var index := clampi(roundi(_scroll_x / STATION_STEP), 0, _station_count() - 1)
	var direction := signi(index - _station_index)
	_station_index = index
	_animate_to_station(index, direction)


func _on_scroller_scrolled(ratio: float) -> void:
	if _phase != Phase.BAR:
		return
	var index := clampi(roundi(ratio * float(_station_count() - 1)), 0, _station_count() - 1)
	if index == _station_index:
		return
	var direction := signi(index - _station_index)
	_station_index = index
	_animate_to_station(index, direction)


func _update_station_ui() -> void:
	_arrow_left.disabled = _station_index <= 0
	_arrow_right.disabled = _station_index >= _station_count() - 1
	_station_title.text = "STATION %d / %d   ·   %s" % [
		_station_index + 1, _station_count(), STATION_NAMES[_station_index]]
	_station_subtitle.text = STATION_SUBTITLES[_station_index]
	_station_dots.current = _station_index


func _pulse_station_title() -> void:
	if _station_title_tween != null:
		_station_title_tween.kill()
	_station_title.modulate.a = 0.0
	_station_subtitle.modulate.a = 0.0
	_station_title_tween = create_tween().set_parallel()
	_station_title_tween.tween_property(_station_title, "modulate:a", 1.0, 0.18)
	_station_title_tween.tween_property(_station_subtitle, "modulate:a", 1.0, 0.28)


# --- Talk ---

func _next_customer() -> void:
	_phase = Phase.ARRIVING
	_customer_data = _pick_customer()
	_required = _roll_recipe(_customer_data)
	_revealed = 0
	_last_customer_id = _customer_data.id
	_last_seen[_customer_data.id] = GameState.served
	# A fresh conversation every visit: hints for 2 of the 3 ingredients, random
	# wording (data/dialogue/<customer id>.txt).
	var conversation := Dialogue.build(_customer_data, _required)
	_lines = _parse_conversation(conversation.text)
	# The ticket only keeps the hint lines, as a reminder of the order.
	_what_they_said = "  ".join(conversation.hints)
	_tray.reset()
	_tray.max_payout = GameState.max_payout(_customer_data)
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
	_ticket.show_order(_customer_data, _what_they_said, _required, _revealed, _customer_data.hidden_recipe, GameState.patience())
	_cancel_scroll_tween()
	_scroll_x = 0.0
	_scroller.ratio = 0.0
	_station_index = 0
	_update_station_ui()
	_set_bar_ui(true)
	Sfx.play("whoosh")
	await _pan_camera(Vector2(0.0, BAR_Y))
	if _phase != Phase.TO_BAR:
		return
	_phase = Phase.BAR
	_tray.active = true
	_ticket.start()
	_pulse_station_title()


# --- Bar ---

# --- Dragging a cup out of the stack ---

func _cup_stack_at(screen_pos: Vector2) -> bool:
	if not _cup_stack.is_visible_in_tree():
		return false
	var world_pos := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	return _cup_stack.get_global_rect().has_point(world_pos)


func _on_cup_stack_pressed() -> void:
	# Normally the press is intercepted in _input before the button sees it.
	# This only fires if the gesture system ever misses, so it just hints.
	if _phase == Phase.BAR and not _tray.cup.present:
		_show_toast("Drag a cup down to the counter!")


func _start_cup_drag() -> void:
	_cup_dragging = true
	var texture := Art.load_texture(Art.ROOT + "cup/empty")
	var ghost := TextureRect.new()
	ghost.texture = texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.size = Vector2(150.0, 150.0)
	ghost.pivot_offset = ghost.size / 2.0
	ghost.mouse_filter = MOUSE_FILTER_IGNORE
	ghost.z_index = 20
	_fx_ui.add_child(ghost)
	_cup_ghost = ghost
	ghost.scale = Vector2(0.7, 0.7)
	ghost.create_tween().tween_property(ghost, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Dim the stack so it reads as "one cup lifted off the pile".
	_cup_stack.modulate.a = 0.45


func _move_cup_drag(screen_pos: Vector2) -> void:
	if _cup_ghost != null:
		_cup_ghost.position = screen_pos - _cup_ghost.size / 2.0
	var over := _over_cup_slot(screen_pos)
	if _cup_ghost != null:
		_cup_ghost.scale = Vector2(0.86, 0.86) if over else Vector2.ONE
	_tray.set_cup_drag_hover(over)


func _finish_cup_drag(screen_pos: Vector2) -> void:
	var dragged := _cup_dragging
	var over := _over_cup_slot(screen_pos)
	_clear_cup_drag()
	if not dragged:
		Sfx.play("denied")
		_show_toast("Drag a cup out of the stack!")
		return
	if not over:
		Sfx.play("denied")
		_show_toast("Set the cup down on the counter!")
		return
	_take_cup()


func _clear_cup_drag() -> void:
	if _cup_ghost != null:
		_cup_ghost.queue_free()
		_cup_ghost = null
	_cup_pending = false
	_cup_dragging = false
	_cup_stack.modulate.a = 1.0
	_tray.set_cup_drag_hover(false)


func _over_cup_slot(screen_pos: Vector2) -> bool:
	return _tray.cup.get_global_rect().grow(60.0).has_point(screen_pos)


func _take_cup() -> void:
	if _phase != Phase.BAR or _tray.cup.present:
		return
	_tray.cup.present = true
	Sfx.play("cup")
	_fly(Art.load_texture(Art.ROOT + "cup/empty"), Palette.BLUSH, _to_screen(_cup_stack.art_center()), 128.0)


func _on_pour_requested(dispenser: Dispenser) -> void:
	var source := _to_screen(dispenser.global_position + Vector2(dispenser.size.x / 2.0, 56.0))
	_pour(dispenser, source)


# --- Dragging ingredients onto the cup ---

func _dispenser_at_screen(screen_pos: Vector2) -> Dispenser:
	var world_pos := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	for node in get_tree().get_nodes_in_group("dispensers"):
		var dispenser := node as Dispenser
		if dispenser != null and dispenser.is_visible_in_tree() and dispenser.get_global_rect().has_point(world_pos):
			return dispenser
	return null


func _begin_pending_drag(dispenser: Dispenser, screen_pos: Vector2) -> void:
	_item_drag = dispenser
	_item_drag_origin = screen_pos
	_item_dragging = false


func _start_item_drag() -> void:
	if _item_drag == null:
		return
	_item_dragging = true
	if _item_drag.needs_machine():
		_item_drag.set_away(true)
	var texture := Art.load_texture(Art.ingredient(_item_drag.ingredient.id))
	if texture == null:
		return
	var ghost := TextureRect.new()
	ghost.texture = texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.size = Vector2(168.0, 168.0)
	ghost.pivot_offset = ghost.size / 2.0
	ghost.mouse_filter = MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.92)
	ghost.z_index = 20
	_fx_ui.add_child(ghost)
	_drag_ghost = ghost
	ghost.scale = Vector2(0.65, 0.65)
	ghost.create_tween().tween_property(ghost, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _move_item_drag(screen_pos: Vector2) -> void:
	# Espresso/Matcha spoons go into the coffee machine, everything else into the cup.
	var to_machine := _item_drag != null and _item_drag.needs_machine()
	var over := _over_machine(screen_pos) if to_machine else _over_cup(screen_pos)
	if _drag_ghost != null:
		_drag_ghost.position = screen_pos - _drag_ghost.size / 2.0
		_drag_ghost.scale = Vector2(0.78, 0.78) if over else Vector2.ONE
		_drag_ghost.modulate.a = 1.0 if over else 0.92
	if to_machine:
		_machine.set_drag_state(true, over)
	else:
		_tray.set_drop_hover(over and _tray.cup.present)


func _finish_item_drag(screen_pos: Vector2) -> void:
	var dispenser := _item_drag
	var dragged := _item_dragging
	var over := _over_cup(screen_pos)
	_clear_item_drag()
	if dispenser == null:
		return
	if dispenser.needs_machine():
		_finish_spoon_drag(dispenser, dragged, screen_pos)
		return
	if not dragged:
		# A plain click still pours, exactly like before.
		_pour(dispenser, _to_screen(dispenser.global_position + Vector2(dispenser.size.x / 2.0, 56.0)))
	elif over:
		_pour(dispenser, screen_pos)
	else:
		Sfx.play("denied")
		_show_toast("Drop it in the cup!")


func _clear_item_drag() -> void:
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	if _item_drag != null and _item_drag.needs_machine() and _machine.brewing() != _item_drag:
		_item_drag.set_away(false)
	_item_drag = null
	_item_dragging = false
	_tray.set_drop_hover(false)
	_machine.set_drag_state(false, false)


func _over_cup(screen_pos: Vector2) -> bool:
	return _tray.cup.get_global_rect().grow(42.0).has_point(screen_pos)


func _over_machine(screen_pos: Vector2) -> bool:
	return _machine.has_world_point(get_viewport().get_canvas_transform().affine_inverse() * screen_pos)


func _pour(dispenser: Dispenser, from_screen: Vector2) -> void:
	if _phase != Phase.BAR:
		return
	if dispenser.needs_machine():
		dispenser.deny()
		_show_toast("Drag it into the coffee machine!")
		return
	var world_origin := get_viewport().get_canvas_transform().affine_inverse() * from_screen
	var price := _pay_for(dispenser, world_origin + Vector2(0, -24))
	if price < 0:
		return
	_tray.cup.reserve(price, false)
	Sfx.play("pour")
	var art := Art.load_texture(Art.ingredient(dispenser.ingredient.id))
	_fly(art, dispenser.ingredient.color, from_screen, 82.0)
	dispenser.dispense()


## Checks there's a cup with room and enough money, then pays (with a "-$" pop at
## `at`, world space). Returns the price paid, or -1 after telling the player why not.
func _pay_for(dispenser: Dispenser, at: Vector2) -> int:
	var cup := _tray.cup
	var price := dispenser.price()
	var problem := ""
	if not cup.present:
		problem = "Drag a cup down first!"
	elif cup.space_left() <= 0:
		problem = "Cup's full!"
	elif not GameState.spend(price):
		problem = "Can't afford that!"
	if problem != "":
		dispenser.deny()
		_show_toast(problem)
		return -1
	_float_text(_fx_world, "-$%d" % price, at, Palette.LOSS)
	return price


func _on_poured(ingredient: IngredientData) -> void:
	_tray.cup.add(ingredient, false)


func _trash() -> void:
	if _phase != Phase.BAR or not _tray.cup.present or _tray.cup.is_empty():
		return
	_cancel_brews()
	if _tray.cup.cost > 0:
		_float_text(_fx_ui, "Wasted $%d" % _tray.cup.cost, _tray_cup_center() + Vector2(0, -120), Palette.LOSS)
	_tray.cup.clear()
	Sfx.play("trash")
	# Nothing left to make a drink with: run's over.
	if GameState.is_broke():
		_end_run()


func _ask() -> void:
	if _phase != Phase.BAR or not _ticket.can_ask():
		return
	_revealed += 1
	_ticket.spend(GameState.ASK_PATIENCE_COST)
	_ticket.set_revealed(_required, _revealed, true)
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
	var dispenser := _machine.brewing()
	_machine.cancel()
	if dispenser != null:
		dispenser.set_away(false)


# --- Coffee machine: drag the Espresso/Matcha spoon in to brew a shot ---

func _finish_spoon_drag(dispenser: Dispenser, dragged: bool, screen_pos: Vector2) -> void:
	if not dragged:
		dispenser.deny()
		_show_toast("Drag it into the coffee machine!")
		return
	if _over_machine(screen_pos):
		if _start_brew(dispenser):
			return
	elif _over_cup(screen_pos):
		Sfx.play("denied")
		_show_toast("Brew it in the coffee machine first!")
	else:
		Sfx.play("denied")
		_show_toast("Drop it in the coffee machine!")


func _start_brew(dispenser: Dispenser) -> bool:
	if _machine.brewing() == dispenser:
		_show_toast("Still brewing!")
		return false
	if _machine.is_busy():
		_show_toast("The machine's busy!")
		Sfx.play("denied")
		return false
	var price := _pay_for(dispenser, _machine.global_position + Vector2(_machine.size.x / 2.0, 0.0))
	if price < 0:
		return false
	_tray.cup.reserve(price, true)
	dispenser.set_away(true)
	_machine.brew(dispenser)
	return true


func _on_brewed(dispenser: Dispenser) -> void:
	dispenser.set_away(false)
	if _phase != Phase.BAR:
		return
	var ingredient := dispenser.ingredient
	_fly(null, ingredient.color, _to_screen(_machine.spout_global_position()), 44.0)
	_tray.cup.add(ingredient, true)


# --- Review ---

func _resolve(stars: int, timed_out: bool) -> void:
	_phase = Phase.TO_TALK
	_ticket.stop()
	_tray.stop_shake()
	_tray.active = false
	_dragging = false
	_clear_item_drag()
	_clear_cup_drag()
	_cancel_scroll_tween()
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
	var review_text := ""
	if not _customer_data.reviews.is_empty():
		# Round to nearest whole star, convert to 0-based index, and clamp to valid array bounds
		var index := clampi(roundi(stars) - 1, 0, _customer_data.reviews.size() - 1)
		review_text = _customer_data.reviews[index]
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
	_cancel_brews()
	_ticket.stop()
	_tray.active = false
	_dragging = false
	_clear_item_drag()
	_clear_cup_drag()
	_cancel_scroll_tween()
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
	var item := _make_item(texture, color, item_size)
	_fx_ui.add_child(item)
	item.position = from - item.size / 2.0
	var target := _tray_cup_center() - item.size / 2.0
	var tween := item.create_tween().set_parallel()
	tween.tween_property(item, "position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(item, "scale", Vector2(0.5, 0.5), 0.35)
	tween.chain().tween_callback(item.queue_free)


## An ingredient image (or a block of its color if there's no art yet) for effects.
func _make_item(texture: Texture2D, color: Color, item_size: float) -> Control:
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
	return item


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
