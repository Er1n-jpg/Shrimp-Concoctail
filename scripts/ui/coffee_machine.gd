class_name CoffeeMachine
extends Control
## The espresso machine. Drag the Espresso or Matcha spoon onto it: the spoon locks
## in under the group head, the little screen fills up while it brews, and when it's
## done the shot goes into your cup and the spoon goes back on the counter.
##
## Art: res://assets/ui/coffee_machine.png (64x64, shown at 4x = 256px). The spots
## below are in that image's own pixels, so if the art changes, tweak these.

signal brewed(dispenser: Dispenser)

const ART_PATH := "res://assets/ui/coffee_machine"
const ART_SCALE := 4.0
## Where the spoon's bowl locks in (just under the group head).
const GROUP_HEAD := Vector2(32.5, 36.0)
## The top of the drip tray (where the shot drips onto).
const DRIP_TRAY_Y := 47.0
## The little screen on the front, used as the brew progress bar.
const SCREEN_RECT := Rect2(11, 10, 30, 5)
## The spoon is drawn at 2x while it's in the machine; SPOON_BOWL is its bowl
## center in the spoon art's own pixels.
const SPOON_SCALE := 2.0
const SPOON_SIZE := 64.0
const SPOON_BOWL := Vector2(47.5, 18.0)
const STEAM_EVERY := 0.12

var _brewing: Dispenser = null
var _brew_tween: Tween
var _steam_timer := 0.0
var _hint_tween: Tween

var _art: ArtSlot
var _spoon: ArtSlot
var _stream: ColorRect
var _screen: ColorRect
var _fill: ColorRect
var _hint: Label
var _fx: Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	_art = _art_slot(ART_PATH, Palette.SLATE, "COFFEE")
	_art.placeholder_border_color = Palette.INK
	_art.placeholder_corner_radius = 20
	_art.placeholder_shadow = 10
	add_child(_art)
	_art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_stream = ColorRect.new()
	_stream.mouse_filter = MOUSE_FILTER_IGNORE
	_stream.visible = false
	add_child(_stream)

	_spoon = _art_slot("", Palette.TAUPE, "")
	_spoon.size = Vector2.ONE * SPOON_SIZE * SPOON_SCALE
	_spoon.visible = false
	add_child(_spoon)

	_screen = ColorRect.new()
	_screen.color = Palette.INK
	_screen.mouse_filter = MOUSE_FILTER_IGNORE
	_screen.visible = false
	add_child(_screen)
	_fill = ColorRect.new()
	_fill.mouse_filter = MOUSE_FILTER_IGNORE
	_screen.add_child(_fill)

	_fx = Control.new()
	_fx.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_fx)

	_hint = Label.new()
	_hint.text = "drop it in!"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.add_theme_color_override("font_color", Palette.BUTTER)
	_hint.add_theme_color_override("font_outline_color", Palette.INK)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.mouse_filter = MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)

	resized.connect(_layout)
	_layout()


func is_busy() -> bool:
	return _brewing != null


func brewing() -> Dispenser:
	return _brewing


## True if `world_point` (same space as get_global_mouse_position()) is over the machine.
func has_world_point(world_point: Vector2) -> bool:
	return get_global_rect().has_point(world_point)


## Where the shot comes out, in world space (for the fly-to-cup effect).
func spout_global_position() -> Vector2:
	return global_position + Vector2(GROUP_HEAD.x, DRIP_TRAY_Y) * _px()


## While a spoon is being dragged: show the hint, and light the machine up when
## the spoon is over it.
func set_drag_state(dragging: bool, hovering: bool) -> void:
	_art.outline_color = Color(Palette.BUTTER, 1.0 if hovering else 0.45) if dragging else Color(0, 0, 0, 0)
	_art.outline_width = 1.0
	if dragging == _hint.visible:
		return
	_hint.visible = dragging
	if _hint_tween != null:
		_hint_tween.kill()
	if dragging:
		_hint_tween = create_tween().set_loops()
		_hint_tween.tween_property(_hint, "modulate:a", 0.45, 0.4)
		_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.4)


## Lock `dispenser`'s spoon in and start brewing. The caller has already paid.
func brew(dispenser: Dispenser) -> void:
	_brewing = dispenser
	var ingredient := dispenser.ingredient
	_spoon.set_art(Art.ingredient(ingredient.id), ingredient.color, "")
	_spoon.visible = true
	_stream.color = ingredient.color.lightened(0.15)
	_fill.color = Palette.BUTTER
	_fill.size.x = 0.0
	_screen.visible = true
	_steam_timer = 0.0
	Sfx.play("brew")

	# Click it in: the spoon drops up into the group head with a little bump.
	var spoon_home := _spoon.position
	_spoon.position = spoon_home + Vector2(0, 14)
	var duration := maxf(ingredient.brew_time, 0.2)
	_brew_tween = create_tween()
	_brew_tween.tween_property(_spoon, "position", spoon_home, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_brew_tween.tween_callback(func() -> void:
		_stream.visible = true
		_stream.scale.y = 0.0)
	_brew_tween.tween_property(_stream, "scale:y", 1.0, 0.12)
	_brew_tween.parallel().tween_property(_fill, "size:x", _screen.size.x - _px(), duration)
	_brew_tween.tween_callback(_finish)


func cancel() -> void:
	if _brew_tween != null:
		_brew_tween.kill()
	_brewing = null
	_reset_visuals()


func _finish() -> void:
	var dispenser := _brewing
	_brewing = null
	_reset_visuals()
	Sfx.play("brew_done")
	_pop()
	brewed.emit(dispenser)


func _reset_visuals() -> void:
	_spoon.visible = false
	_stream.visible = false
	_screen.visible = false
	_art.position.x = 0.0


func _process(delta: float) -> void:
	if _brewing == null:
		return
	# Rumble and puff steam while brewing.
	_art.position.x = _px() * (1.0 if Engine.get_process_frames() % 6 < 3 else 0.0)
	_steam_timer -= delta
	if _steam_timer <= 0.0:
		_steam_timer = STEAM_EVERY
		_puff()


func _puff() -> void:
	var puff := ColorRect.new()
	var s := _px() * (2.0 if randf() < 0.5 else 3.0)
	puff.size = Vector2(s, s)
	puff.color = Color(Palette.CREAM, 0.8)
	puff.mouse_filter = MOUSE_FILTER_IGNORE
	_fx.add_child(puff)
	puff.position = Vector2(randf_range(14.0, 46.0), 5.0) * _px() - puff.size / 2.0
	var tween := puff.create_tween().set_parallel()
	tween.tween_property(puff, "position:y", puff.position.y - randf_range(50.0, 90.0), 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "position:x", puff.position.x + randf_range(-16.0, 16.0), 0.7)
	tween.tween_property(puff, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(puff.queue_free)


func _pop() -> void:
	_art.pivot_offset = _art.size / 2.0
	var tween := create_tween()
	tween.tween_property(_art, "scale", Vector2(1.04, 0.96), 0.06)
	tween.tween_property(_art, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _layout() -> void:
	if _spoon == null:
		return
	var px := _px()
	_spoon.position = GROUP_HEAD * px - SPOON_BOWL * SPOON_SCALE
	var bowl_bottom := GROUP_HEAD.y + 5.0
	_stream.position = Vector2(GROUP_HEAD.x - 0.5, bowl_bottom) * px
	_stream.size = Vector2(1.0, DRIP_TRAY_Y - bowl_bottom) * px
	_screen.position = SCREEN_RECT.position * px
	_screen.size = SCREEN_RECT.size * px
	_fill.position = Vector2(px, px) * 0.5
	_fill.size.y = _screen.size.y - px
	_hint.position = Vector2(0.0, -48.0)
	_hint.size = Vector2(size.x, 44.0)


## Screen pixels per art pixel (4 when the machine is 256px wide).
func _px() -> float:
	return size.x / 64.0 if size.x > 0.0 else ART_SCALE


func _art_slot(path: String, color: Color, text: String) -> ArtSlot:
	var slot := ArtSlot.new()
	slot.set_art(path, color, text)
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	return slot
