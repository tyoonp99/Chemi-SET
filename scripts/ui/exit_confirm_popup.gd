class_name ExitConfirmPopup
extends ColorRect

signal confirmed

@onready var _confirm_button: Button = %ExitConfirmButton
@onready var _cancel_button: Button = %ExitCancelButton

func _ready() -> void:
	_confirm_button.pressed.connect(func() -> void: confirmed.emit())
	_cancel_button.pressed.connect(hide)
	hide()
