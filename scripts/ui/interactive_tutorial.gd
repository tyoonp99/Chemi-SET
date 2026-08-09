class_name InteractiveTutorial
extends ColorRect

signal completed
signal dismissed

const CARD_ATTRIBUTES := [
	{"shape": 2, "color": 2, "state": 0},
	{"shape": 1, "color": 0, "state": 0},
	{"shape": 0, "color": 0, "state": 2},
	{"shape": 0, "color": 0, "state": 0},
	{"shape": 2, "color": 0, "state": 0},
	{"shape": 2, "color": 2, "state": 1},
	{"shape": 1, "color": 1, "state": 1},
	{"shape": 1, "color": 1, "state": 0},
	{"shape": 1, "color": 2, "state": 1}
]
const REQUIRED_SET_COUNT := 4
const ANALYSIS_NEUTRAL_STYLE := preload("res://resources/styles/tutorial/analysis_neutral_style.tres")
const ANALYSIS_SUCCESS_STYLE := preload("res://resources/styles/tutorial/analysis_success_style.tres")
const ANALYSIS_ERROR_STYLE := preload("res://resources/styles/tutorial/analysis_error_style.tres")
const CARD_NORMAL_STYLE := preload("res://resources/styles/cards/card_normal_style.tres")
const HINT_CARD_STYLE := preload("res://resources/styles/tutorial/hint_card_style.tres")
const ANALYSIS_NEUTRAL_COLOR := Color(0.72, 0.8, 0.87, 1)
const ANALYSIS_SUCCESS_COLOR := Color(0.67, 1.0, 0.76, 1)
const ANALYSIS_ERROR_COLOR := Color(1.0, 0.67, 0.72, 1)
const SELECTED_CARD_COLOR := Color(0.36, 0.82, 1.0, 1.0)

@onready var _instruction: Label = %Instruction
@onready var _board: GridContainer = %Board
@onready var _shape_analysis: PanelContainer = %ShapeAnalysis
@onready var _color_analysis: PanelContainer = %ColorAnalysis
@onready var _state_analysis: PanelContainer = %StateAnalysis
@onready var _shape_result: Label = %ShapeResult
@onready var _color_result: Label = %ColorResult
@onready var _state_result: Label = %StateResult
@onready var _synthesis_button: Button = %SynthesisButton
@onready var _completion_button: Button = %CompletionButton
@onready var _hint_button: Button = %HintButton
@onready var _close_button: Button = %CloseButton

var _selected_indices: Array[int] = []
var _found_set_keys: Dictionary = {}
var _hinted_indices: Array[int] = []
var _all_sets: Array[Array] = []
var _stage := 0

func _ready() -> void:
	for index in _board.get_child_count():
		var card := _board.get_child(index) as Button
		card.pressed.connect(_on_card_pressed.bind(index))
	_synthesis_button.pressed.connect(_on_synthesis_pressed)
	_completion_button.pressed.connect(_on_completion_pressed)
	_hint_button.pressed.connect(_on_hint_pressed)
	_close_button.pressed.connect(dismiss)
	hide()

func open() -> void:
	_stage = 0
	_selected_indices.clear()
	_found_set_keys.clear()
	_hinted_indices.clear()
	_all_sets = _find_all_sets()
	_instruction.text = "이 보드에는 합성이 %d개 있습니다.\n분석 바를 보며 모두 찾아보세요. (0 / %d)" % [_all_sets.size(), _all_sets.size()]
	_synthesis_button.disabled = true
	_completion_button.disabled = true
	_hint_button.disabled = false
	for index in _board.get_child_count():
		var card := _board.get_child(index) as Button
		card.disabled = false
	_refresh_card_visuals()
	_set_analysis_waiting()
	show()

func dismiss() -> void:
	hide()
	dismissed.emit()

func _on_card_pressed(index: int) -> void:
	if _stage != 0:
		return
	if not _hinted_indices.is_empty():
		_hinted_indices.clear()
	if index in _selected_indices:
		_selected_indices.erase(index)
	else:
		if _selected_indices.size() == 3:
			return
		_selected_indices.append(index)
	_refresh_card_visuals()
	_update_analysis()
	_synthesis_button.disabled = _selected_indices.size() != 3
	if _selected_indices.size() == 3:
		_instruction.text = "아래 분석 결과를 확인해 보세요.\n세 항목이 모두 초록이면 합성입니다."
	else:
		_instruction.text = "합성 %d / %d · 카드 3장을 골라 보세요. (%d / 3)" % [_found_set_keys.size(), _all_sets.size(), _selected_indices.size()]

func _on_synthesis_pressed() -> void:
	if _stage != 0:
		return
	if _selected_indices.size() != 3:
		return
	if not SetRules.is_set(_cards_for_indices(_selected_indices)):
		_instruction.text = "아직 합성이 아니에요. 빨간 항목을 바꿔 보세요."
		return
	var set_key := _selection_key(_selected_indices)
	if _found_set_keys.has(set_key):
		_instruction.text = "이미 찾은 합성입니다. 다른 조합을 찾아보세요."
		return
	_found_set_keys[set_key] = true
	_selected_indices.clear()
	_set_analysis_waiting()
	_refresh_card_visuals()
	if _found_set_keys.size() == REQUIRED_SET_COUNT:
		_stage = 1
		_instruction.text = "합성 탐색 완료!\n4개의 합성을 모두 찾았어요.\n이제 완료를 눌러 보세요."
		_synthesis_button.disabled = true
		_completion_button.disabled = false
		_hint_button.disabled = true
		for card_node in _board.get_children():
			(card_node as Button).disabled = true
		return
	_instruction.text = "합성 %d / %d!\n남은 합성을 찾아보세요." % [_found_set_keys.size(), _all_sets.size()]
	_synthesis_button.disabled = true

func _on_hint_pressed() -> void:
	if _stage != 0:
		return
	for set_indices in _all_sets:
		if not _found_set_keys.has(_selection_key(set_indices)):
			_selected_indices.clear()
			_hinted_indices.assign(set_indices)
			_refresh_card_visuals()
			_update_analysis_for_indices(_hinted_indices)
			_synthesis_button.disabled = true
			_instruction.text = "정답 하나를 표시했어요.\n세 카드를 직접 선택해 합성해 보세요."
			return

func _on_completion_pressed() -> void:
	if _stage != 1:
		return
	Global.mark_tutorial_completed()
	completed.emit()
	hide()

func _set_analysis_waiting() -> void:
	_set_analysis_cell(_shape_analysis, _shape_result, "선택 대기", ANALYSIS_NEUTRAL_STYLE, ANALYSIS_NEUTRAL_COLOR)
	_set_analysis_cell(_color_analysis, _color_result, "선택 대기", ANALYSIS_NEUTRAL_STYLE, ANALYSIS_NEUTRAL_COLOR)
	_set_analysis_cell(_state_analysis, _state_result, "선택 대기", ANALYSIS_NEUTRAL_STYLE, ANALYSIS_NEUTRAL_COLOR)

func _update_analysis() -> void:
	if _selected_indices.size() != 3:
		_set_analysis_waiting()
		return
	_update_analysis_for_indices(_selected_indices)

func _update_analysis_for_indices(indices: Array[int]) -> void:
	_update_attribute_analysis("shape", indices, _shape_analysis, _shape_result)
	_update_attribute_analysis("color", indices, _color_analysis, _color_result)
	_update_attribute_analysis("state", indices, _state_analysis, _state_result)

func _update_attribute_analysis(attribute: String, indices: Array[int], panel: PanelContainer, label: Label) -> void:
	var values: Array[int] = []
	for index in indices:
		values.append(int(CARD_ATTRIBUTES[index][attribute]))
	var unique_values := {}
	for value in values:
		unique_values[value] = true
	var distinct_count := unique_values.size()
	if distinct_count == 1:
		_set_analysis_cell(panel, label, "모두 같음 ✓", ANALYSIS_SUCCESS_STYLE, ANALYSIS_SUCCESS_COLOR)
	elif distinct_count == 3:
		_set_analysis_cell(panel, label, "모두 다름 ✓", ANALYSIS_SUCCESS_STYLE, ANALYSIS_SUCCESS_COLOR)
	else:
		_set_analysis_cell(panel, label, "2개만 같음 ✕", ANALYSIS_ERROR_STYLE, ANALYSIS_ERROR_COLOR)

func _set_analysis_cell(panel: PanelContainer, label: Label, text: String, style: StyleBox, font_color: Color) -> void:
	panel.add_theme_stylebox_override("panel", style)
	label.text = text
	label.add_theme_color_override("font_color", font_color)

func _find_all_sets() -> Array[Array]:
	var sets: Array[Array] = []
	for first in range(CARD_ATTRIBUTES.size() - 2):
		for second in range(first + 1, CARD_ATTRIBUTES.size() - 1):
			for third in range(second + 1, CARD_ATTRIBUTES.size()):
				var indices: Array[int] = [first, second, third]
				if SetRules.is_set(_cards_for_indices(indices)):
					sets.append(indices)
	return sets

func _cards_for_indices(indices: Array[int]) -> Array:
	var cards: Array = []
	for index in indices:
		cards.append(CARD_ATTRIBUTES[index])
	return cards

func _selection_key(indices: Array[int]) -> String:
	var ordered_indices := indices.duplicate()
	ordered_indices.sort()
	var parts := PackedStringArray()
	for index in ordered_indices:
		parts.append(str(index))
	return ",".join(parts)

func _refresh_card_visuals() -> void:
	for index in _board.get_child_count():
		var card := _board.get_child(index) as Button
		if index in _selected_indices:
			card.modulate = SELECTED_CARD_COLOR
			_set_card_style(card, CARD_NORMAL_STYLE)
		elif index in _hinted_indices:
			card.modulate = Color.WHITE
			_set_card_style(card, HINT_CARD_STYLE)
		else:
			card.modulate = Color.WHITE
			_set_card_style(card, CARD_NORMAL_STYLE)

func _set_card_style(card: Button, style: StyleBox) -> void:
	card.add_theme_stylebox_override("normal", style)
	card.add_theme_stylebox_override("hover", style)
	card.add_theme_stylebox_override("pressed", style)
