class_name InteractiveTutorial
extends ColorRect

signal completed

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
	_close_button.pressed.connect(hide)
	hide()

func open() -> void:
	_stage = 0
	_selected_indices.clear()
	_instruction.text = "합성되는 카드 3장을 선택해 보세요."
	_progress.text = "1 / 2  카드 선택"
	_synthesis_button.disabled = false
	_completion_button.disabled = true
	for index in _board.get_child_count():
		var card := _board.get_child(index) as Button
		card.disabled = false
		card.modulate = Color.WHITE
	show()

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
	_instruction.text = "합성되는 카드 3장을 선택해 보세요. (%d / 3)" % _selected_indices.size()

func _on_synthesis_pressed() -> void:
	if _stage != 0:
		return
	var sorted_selection := _selected_indices.duplicate()
	sorted_selection.sort()
	if sorted_selection != TARGET_SELECTION:
		_instruction.text = "아직 아니에요. 왼쪽 위 · 가운데 · 오른쪽 아래를 비교해 보세요."
		return
	_stage = 1
	_instruction.text = "합성 성공! 이 보드의 합성을 모두 찾았다면 완료를 선언합니다."
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
