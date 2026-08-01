class_name GameHud
extends Control

signal pause_pressed

@onready var _score_value: Label = %ScoreValueLabel
@onready var _time_value: Label = %TimeValueLabel
@onready var _settings_button: Button = %SettingsButton

func _ready() -> void:
	_settings_button.pressed.connect(func() -> void: pause_pressed.emit())

func set_score(score: int) -> void:
	_score_value.text = str(score)

func set_time(seconds_left: int, unlimited: bool) -> void:
	if unlimited:
		_time_value.text = "무제한"
		return
	var minutes := floori(float(seconds_left) / 60.0)
	_time_value.text = "%d:%02d" % [minutes, seconds_left % 60]
