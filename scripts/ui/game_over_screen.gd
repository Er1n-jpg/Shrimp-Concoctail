class_name GameOverScreen
extends Control
## "You went broke" screen with the run result and a retry button.

signal retry_pressed

@onready var _survived: Label = $Panel/Box/Survived
@onready var _best: Label = $Panel/Box/Best
@onready var _new_best: Label = $Panel/Box/NewBest
@onready var _retry: Button = $Panel/Box/Retry


func _ready() -> void:
	visible = false
	_retry.focus_mode = FOCUS_NONE
	_retry.pressed.connect(func() -> void: retry_pressed.emit())


func show_result(served: int, best: int, new_best: bool) -> void:
	_survived.text = "Survived %d customer%s" % [served, "" if served == 1 else "s"]
	_best.text = "Best: %d" % best
	_new_best.visible = new_best
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
