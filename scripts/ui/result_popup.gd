class_name ResultPopup
extends ColorRect

signal restart_pressed
signal title_pressed

@onready var _result_label: Label = %ResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _title_button: Button = %TitleButton

func _ready() -> void:
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_title_button.pressed.connect(func() -> void: title_pressed.emit())

func show_result(message: String) -> void:
	_result_label.text = message
	show()
