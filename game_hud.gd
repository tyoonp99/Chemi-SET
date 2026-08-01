class_name GameHud
extends Control

signal pause_pressed

@onready var _score_value: Label = %ScoreValueLabel
@onready var _combo_value: Label = %ComboValueLabel
@onready var _time_value: Label = %TimeValueLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _score_box: VBoxContainer = %ScoreBox
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _feedback_timer: Timer = %FeedbackTimer

func _ready() -> void:
	_settings_button.pressed.connect(func() -> void: pause_pressed.emit())
	_feedback_timer.timeout.connect(_feedback_label.hide)

func set_score(score: int, combo: int) -> void:
	_score_value.text = str(score)
	_combo_value.text = "콤보 %d" % combo

func set_time(seconds_left: int, unlimited: bool) -> void:
	if unlimited:
		_time_value.text = "무제한"
		return
	var minutes := floori(float(seconds_left) / 60.0)
	_time_value.text = "%d:%02d" % [minutes, seconds_left % 60]

func configure_for_mode(is_practice: bool) -> void:
	_score_box.visible = not is_practice

func show_feedback(message: String, positive: bool) -> void:
	_feedback_label.text = message
	_feedback_label.add_theme_color_override("font_color", Color("72e6a6") if positive else Color("ff8f8f"))
	_feedback_label.show()
	_feedback_timer.start()
