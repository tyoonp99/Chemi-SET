class_name InteractiveTutorial
extends ColorRect

signal completed
signal dismissed

const TARGET_SELECTION := [0, 4, 8]

@onready var _instruction: Label = %Instruction
@onready var _progress: Label = %Progress
@onready var _board: GridContainer = %Board
@onready var _synthesis_button: Button = %SynthesisButton
@onready var _completion_button: Button = %CompletionButton
@onready var _close_button: Button = %CloseButton

var _selected_indices: Array[int] = []
var _stage := 0

func _ready() -> void:
	for index in _board.get_child_count():
		var card := _board.get_child(index) as Button
		card.pressed.connect(_on_card_pressed.bind(index))
	_synthesis_button.pressed.connect(_on_synthesis_pressed)
	_completion_button.pressed.connect(_on_completion_pressed)
	_close_button.pressed.connect(dismiss)
	hide()

func open() -> void:
	_stage = 0
	_selected_indices.clear()
	_instruction.text = "모양·색상·내용물이 모두 같거나 모두 다른 카드 3장을 골라 보세요."
	_progress.text = "1 / 2  카드 선택"
	_synthesis_button.disabled = false
	_completion_button.disabled = true
	for index in _board.get_child_count():
		var card := _board.get_child(index) as Button
		card.disabled = false
		card.modulate = Color.WHITE
	show()

func dismiss() -> void:
	hide()
	dismissed.emit()

func _on_card_pressed(index: int) -> void:
	if _stage != 0:
		return
	if index in _selected_indices:
		_selected_indices.erase(index)
	else:
		if _selected_indices.size() == 3:
			return
		_selected_indices.append(index)
	var card := _board.get_child(index) as Button
	card.modulate = Color(0.36, 0.82, 1.0, 1.0) if index in _selected_indices else Color.WHITE
	_instruction.text = "모양·색상·내용물이 모두 같거나 모두 다른 카드 3장을 골라 보세요. (%d / 3)" % _selected_indices.size()

func _on_synthesis_pressed() -> void:
	if _stage != 0:
		return
	var sorted_selection := _selected_indices.duplicate()
	sorted_selection.sort()
	if sorted_selection != TARGET_SELECTION:
		_instruction.text = "힌트: 왼쪽 위·가운데·오른쪽 아래는 모양·색상은 같고, 내용물은 모두 달라요."
		return
	_stage = 1
	_instruction.text = "정답! 이렇게 각 속성이 모두 같거나 모두 다르면 ‘합성’이 됩니다. 이 보드는 이 조합 하나가 전부예요. 완료를 눌러 보세요."
	_progress.text = "2 / 2  완료 선언"
	_synthesis_button.disabled = true
	_completion_button.disabled = false
	for card_node in _board.get_children():
		(card_node as Button).disabled = true

func _on_completion_pressed() -> void:
	if _stage != 1:
		return
	Global.mark_tutorial_completed()
	completed.emit()
	hide()
