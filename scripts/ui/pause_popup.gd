class_name PausePopup
extends ColorRect

signal resume_pressed
signal restart_pressed
signal title_pressed

@onready var _resume_button: Button = %ContinueButton
@onready var _restart_button: Button = %RestartButton
@onready var _title_button: Button = %TitleButton
@onready var _sound_button: Button = %SoundButton
@onready var _haptic_button: Button = %HapticButton

func _ready() -> void:
	_resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_title_button.pressed.connect(func() -> void: title_pressed.emit())
	_sound_button.pressed.connect(_on_sound_button_pressed)
	_haptic_button.pressed.connect(_on_haptic_button_pressed)
	visibility_changed.connect(_update_settings_buttons)
	_update_settings_buttons()

func _on_sound_button_pressed() -> void:
	var enabled := not Global.is_sfx_enabled()
	Global.set_sfx_enabled(enabled)
	SoundManager.set_sfx_enabled(enabled)
	_update_settings_buttons()

func _on_haptic_button_pressed() -> void:
	Global.set_haptics_enabled(not Global.is_haptics_enabled())
	_update_settings_buttons()

func _update_settings_buttons() -> void:
	_sound_button.text = "🔊 효과음 ON" if Global.is_sfx_enabled() else "🔇 효과음 OFF"
	_haptic_button.text = "📳 진동 ON" if Global.is_haptics_enabled() else "📴 진동 OFF"
