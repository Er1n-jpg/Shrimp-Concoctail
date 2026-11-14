extends Control
## Stats bar at the top of the screen.
## Background art: res://assets/ui/hud_bar.png (stretched to fit).

@onready var _money: Label = $Bar/Money
@onready var _served: Label = $Bar/Served
@onready var _streak: Label = $Bar/Streak
@onready var _best: Label = $Bar/Best

var _last_money := -1


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	GameState.served_changed.connect(func(n: int) -> void: _served.text = "Served  %d" % n)
	GameState.streak_changed.connect(_on_streak_changed)
	GameState.best_changed.connect(func(n: int) -> void: _best.text = "Best  %d" % n)
	_on_money_changed(GameState.money)
	_served.text = "Served  %d" % GameState.served
	_on_streak_changed(GameState.streak)
	_best.text = "Best  %d" % GameState.best


func _on_money_changed(money: int) -> void:
	_money.text = "$%d" % money
	if _last_money >= 0 and money != _last_money:
		var flash := Color(0.4, 1.0, 0.45) if money > _last_money else Color(1.0, 0.4, 0.4)
		_pulse(_money, flash)
	_last_money = money


func _on_streak_changed(streak: int) -> void:
	if streak == 0:
		_streak.text = "Streak  -"
	else:
		_streak.text = "Streak  %d  (x%.2f)" % [streak, GameState.streak_multiplier()]
		_pulse(_streak, Color(1.0, 0.6, 0.2))


func _pulse(label: Label, color: Color) -> void:
	label.pivot_offset = label.size / 2.0
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.08)
	tween.parallel().tween_property(label, "modulate", color, 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(label, "modulate", Color.WHITE, 0.3)
