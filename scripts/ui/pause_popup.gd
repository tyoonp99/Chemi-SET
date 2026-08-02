class_name PausePopup
extends ColorRect

signal resume_pressed
signal restart_pressed
signal title_pressed

@onready var _resume_button: Button = %ContinueButton
@onready var _restart_button: Button = %RestartButton
@onready var _title_button: Button = %TitleButton

func _ready() -> void:
	_resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_title_button.pressed.connect(func() -> void: title_pressed.emit())
