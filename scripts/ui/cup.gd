class_name Cup
extends Control
## The drink in the cup tray, drawn with the cup sprites in res://assets/cup/:
##   empty, 35, 65, full  (+ optional _ice and _sugar_rim variants, e.g. full_ice_sugar_rim)
## Missing variants fall back to the closest one. The grey liquid in the art is tinted
## to the drink's color by shaders/liquid_tint.gdshader: the last thing poured until
## it's shaken, then the blended mix.

signal changed

## Pours at or below each count use that fill sprite.
const FILL_LEVELS := [[0, "empty"], [2, "35"], [4, "65"], [999, "full"]]
const UNMIXED_GREY := Color(0.41, 0.41, 0.41)

## Whether there's a cup in the tray at all (you grab one from the stack first).
var present: bool = false:
	set(value):
		present = value
		_changed()
## Ingredients in pour order.
var layers: Array[IngredientData] = []
## Money spent on this cup so far.
var cost: int = 0
## Pours that are paid for but still brewing.
var pending: int = 0
var ice: bool = false
var shaken: bool = false

var _tint_tween: Tween
var _droplet_timer := 0.0
var _shake_time := 0.0

@onready var _sprite: TextureRect = $Sprite
@onready var _lid: ArtSlot = $Lid
@onready var _fx: Control = $Fx


func _ready() -> void:
	pivot_offset = size / 2.0
	_lid.visible = false
	_changed()


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
	shaken = false
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
	ice = false
	shaken = false
	_changed()


func set_ice(on: bool) -> void:
	ice = on
	_changed()


## Average color of everything poured.
func mix_color() -> Color:
	if layers.is_empty():
		return UNMIXED_GREY
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for ing in layers:
		r += ing.color.r
		g += ing.color.g
		b += ing.color.b
	var n := float(layers.size())
	return Color(r / n, g / n, b / n)


# --- Shaking (driven every frame by the cup tray while the button is held) ---

func shake_step(delta: float, progress: float) -> void:
	_lid.visible = true
	_shake_time += delta
	var strength := lerpf(0.5, 1.0, progress)
	rotation = sin(_shake_time * 38.0) * 0.22 * strength
	_sprite.position.y = absf(sin(_shake_time * 19.0)) * -14.0 * strength
	_lid.position.y = _sprite.position.y - 26.0
	_droplet_timer -= delta
	if _droplet_timer <= 0.0:
		_droplet_timer = 0.05
		_spawn_droplet(mix_color(), 1.0)


func stop_shake() -> void:
	_shake_time = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "rotation", 0.0, 0.12)
	tween.tween_property(_sprite, "position:y", 0.0, 0.12)
	tween.tween_property(_lid, "position:y", -26.0, 0.12)


func finish_shake() -> void:
	stop_shake()
	shaken = true
	# Lid pops off, sparkles, and the liquid blends into the mix color.
	var lid_tween := create_tween()
	lid_tween.tween_property(_lid, "position:y", -110.0, 0.18).set_ease(Tween.EASE_OUT)
	lid_tween.parallel().tween_property(_lid, "modulate:a", 0.0, 0.25)
	lid_tween.tween_callback(func() -> void:
		_lid.visible = false
		_lid.modulate.a = 1.0
		_lid.position.y = -26.0)
	for i in 14:
		_spawn_droplet(Palette.BUTTER, 1.6)
	_changed()


func _spawn_droplet(color: Color, power: float) -> void:
	var drop := ColorRect.new()
	drop.color = color
	drop.size = Vector2(10, 10)
	drop.mouse_filter = MOUSE_FILTER_IGNORE
	_fx.add_child(drop)
	drop.position = Vector2(size.x / 2.0 + randf_range(-50.0, 50.0), 40.0)
	var target := drop.position + Vector2(randf_range(-140.0, 140.0), randf_range(-150.0, -40.0)) * power
	var tween := drop.create_tween().set_parallel()
	tween.tween_property(drop, "position", target, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(drop, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(drop.queue_free)


# --- Visuals ---

func _changed() -> void:
	if not is_node_ready():
		return
	visible = present
	_sprite.texture = _pick_texture()
	var target := UNMIXED_GREY
	if not layers.is_empty():
		target = mix_color() if shaken else layers.back().color
	var mat := _sprite.material as ShaderMaterial
	if _tint_tween != null:
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(mat, "shader_parameter/tint", target, 0.35 if shaken else 0.12)
	changed.emit()


func _pick_texture() -> Texture2D:
	var level := "empty"
	for entry in FILL_LEVELS:
		if layers.size() <= int(entry[0]):
			level = entry[1]
			break
	var has_sugar := contents().has("sugar")
	var candidates: Array[String] = []
	if level != "empty":
		if ice and has_sugar:
			candidates.append(level + "_ice_sugar_rim")
		if has_sugar:
			candidates.append(level + "_sugar_rim")
		if ice:
			candidates.append(level + "_ice")
	candidates.append(level)
	for name in candidates:
		var tex := Art.load_texture(Art.ROOT + "cup/" + name)
		if tex != null:
			return tex
	return null
