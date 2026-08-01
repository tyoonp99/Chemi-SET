class_name HighScorePopup
extends ColorRect

signal submitted(player_name: String)

@onready var _name_input: LineEdit = %NameInput
@onready var _submit_button: Button = %SubmitButton

func _ready() -> void:
	_submit_button.pressed.connect(_submit)
	_name_input.text_submitted.connect(func(_text: String) -> void: _submit())

func show_entry() -> void:
	_name_input.clear()
	show()
	_name_input.grab_focus()

func _submit() -> void:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9]")
	var player_name := regex.sub(_name_input.text, "", true).strip_edges().to_upper().left(3)
	if player_name.is_empty():
		player_name = "P1"
	submitted.emit(player_name)
