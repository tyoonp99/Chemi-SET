class_name ModeGyulHap
extends Control

signal score_changed(score: int, combo: int)
signal time_changed(seconds_left: int, unlimited: bool)
signal game_over(result: Dictionary)

var _selected_cards: Array[int] = []
var _full_deck: Array[Dictionary] = []
var _board_cards: Array[Dictionary] = []
var _found_hap_keys: Dictionary = {}
var _score := 0
var _combo := 0
var _max_combo := 0
var _is_game_over := false
var _last_time := -1
var _config: Dictionary = {}

@onready var _grid: GridContainer = %GridContainer
@onready var _timer: Timer = %Timer
@onready var _selection_label: Label = %SelectionLabel
@onready var _hap_button: Button = %HapButton
@onready var _gyul_button: Button = %GyulButton

func _ready() -> void:
	for index in _grid.get_child_count():
		(_grid.get_child(index) as Button).pressed.connect(_on_card_pressed.bind(index))
	_hap_button.pressed.connect(_on_hap_pressed)
	_gyul_button.pressed.connect(_on_gyul_pressed)
	_timer.timeout.connect(_on_timer_timeout)

func start(config: Dictionary) -> void:
	_config = config.duplicate(true)
	_score = 0
	_combo = 0
	_max_combo = 0
	_is_game_over = false
	_last_time = -1
	_redeal_board()
	_timer.wait_time = int(_config.get("time_limit", 180))
	_timer.start()
	score_changed.emit(_score, _combo)
	_emit_time()

func _process(_delta: float) -> void:
	if not _is_game_over:
		_emit_time()

func _on_card_pressed(index: int) -> void:
	if _is_game_over:
		return
	var card_button := _grid.get_child(index) as Button
	if index in _selected_cards:
		_selected_cards.erase(index)
		card_button.modulate = Color.WHITE
	elif _selected_cards.size() < 3:
		_selected_cards.append(index)
		card_button.modulate = Color(0.5, 0.5, 0.5, 0.8)
	_update_selection_ui()

func _on_hap_pressed() -> void:
	if _selected_cards.size() != 3 or _is_game_over:
		return
	var selected_data: Array = []
	for index in _selected_cards:
		selected_data.append(_board_cards[index])
	if SetRules.is_set(selected_data):
		var hap_key := _selected_hap_key()
		if not _found_hap_keys.has(hap_key):
			_found_hap_keys[hap_key] = true
			_combo += 1
			_max_combo = max(_max_combo, _combo)
			_score += int(_config.get("hap_points", 100))
		_clear_selection()
	else:
		_apply_penalty(int(_config.get("wrong_hap_penalty", 100)))
		_clear_selection()
	score_changed.emit(_score, _combo)

func _on_gyul_pressed() -> void:
	if _is_game_over:
		return
	if _found_hap_keys.size() == _count_set_combinations():
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		_score += int(_config.get("gyul_points", 400))
		_redeal_board()
	else:
		_apply_penalty(int(_config.get("wrong_gyul_penalty", 150)))
		_clear_selection()
	score_changed.emit(_score, _combo)

func _apply_penalty(points: int) -> void:
	_score = max(0, _score - points)
	_combo = 0

func _redeal_board() -> void:
	_selected_cards.clear()
	_found_hap_keys.clear()
	_full_deck = CardCatalog.create_full_deck()
	_full_deck.shuffle()
	_board_cards.clear()
	for index in _grid.get_child_count():
		var card_data: Dictionary = _full_deck.pop_back()
		_board_cards.append(card_data)
		_set_card_icon(index, card_data)
		(_grid.get_child(index) as Button).modulate = Color.WHITE
	_update_selection_ui()

func _clear_selection() -> void:
	for index in _selected_cards:
		(_grid.get_child(index) as Button).modulate = Color.WHITE
	_selected_cards.clear()
	_update_selection_ui()

func _update_selection_ui() -> void:
	_selection_label.text = "선택: %d / 3" % _selected_cards.size()
	_hap_button.disabled = _selected_cards.size() != 3

func _count_set_combinations() -> int:
	var count := 0
	for first_index in range(_board_cards.size() - 2):
		for second_index in range(first_index + 1, _board_cards.size() - 1):
			for third_index in range(second_index + 1, _board_cards.size()):
				if SetRules.is_set([
					_board_cards[first_index],
					_board_cards[second_index],
					_board_cards[third_index]
				]):
					count += 1
	return count

func _selected_hap_key() -> String:
	var sorted_indices: Array[int] = _selected_cards.duplicate()
	sorted_indices.sort()
	return "%d-%d-%d" % [sorted_indices[0], sorted_indices[1], sorted_indices[2]]

func _set_card_icon(index: int, card_data: Dictionary) -> void:
	(_grid.get_child(index) as Button).icon = load(CardCatalog.texture_path_for(card_data))

func _emit_time() -> void:
	var seconds_left := ceili(_timer.time_left)
	if seconds_left != _last_time:
		_last_time = seconds_left
		time_changed.emit(seconds_left, false)

func _on_timer_timeout() -> void:
	if _is_game_over:
		return
	_is_game_over = true
	time_changed.emit(0, false)
	game_over.emit({
		"mode": Global.MODE_GYULHAP,
		"score": _score,
		"combo": _max_combo
	})
