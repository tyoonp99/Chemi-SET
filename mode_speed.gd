class_name ModeSpeed
extends Control

signal score_changed(score: int, combo: int)
signal time_changed(seconds_left: int, unlimited: bool)
signal game_over(result: Dictionary)

var _selected_cards: Array[int] = []
var _full_deck: Array[Dictionary] = []
var _board_cards: Array[Dictionary] = []
var _score := 0
var _combo := 0
var _max_combo := 0
var _is_game_over := false
var _is_unlimited := false
var _last_time := -1
var _mode_id: StringName = Global.MODE_SPEED
var _scoring: Dictionary = {}

@onready var _grid: GridContainer = %GridContainer
@onready var _timer: Timer = %Timer

func _ready() -> void:
	for index in _grid.get_child_count():
		var card_button := _grid.get_child(index) as Button
		card_button.pressed.connect(_on_card_pressed.bind(index))
	_timer.timeout.connect(_on_timer_timeout)

func start(config: Dictionary) -> void:
	_mode_id = StringName(config.get("mode_id", Global.MODE_SPEED))
	_is_unlimited = int(config.get("time_limit", 60)) <= 0
	var scoring_config: Variant = config.get("scoring", {})
	_scoring = scoring_config.duplicate(true) if scoring_config is Dictionary else {}
	_build_board()
	score_changed.emit(_score, _combo)
	if _is_unlimited:
		_timer.stop()
		time_changed.emit(0, true)
	else:
		_timer.wait_time = int(config.get("time_limit", 60))
		_timer.start()
		_emit_time()

func _process(_delta: float) -> void:
	if not _is_game_over and not _is_unlimited:
		_emit_time()

func _build_board() -> void:
	_selected_cards.clear()
	_full_deck = CardCatalog.create_full_deck()
	_full_deck.shuffle()
	_board_cards.clear()
	_score = 0
	_combo = 0
	_max_combo = 0
	_is_game_over = false
	_last_time = -1
	for index in _grid.get_child_count():
		var card_data: Dictionary = _full_deck.pop_back()
		_board_cards.append(card_data)
		_set_card_icon(index, card_data)
	_ensure_answer_available()

func _on_card_pressed(index: int) -> void:
	if _is_game_over:
		return
	var card_button := _grid.get_child(index) as Button
	if index in _selected_cards:
		_selected_cards.erase(index)
		card_button.modulate = Color.WHITE
	else:
		_selected_cards.append(index)
		card_button.modulate = Color(0.5, 0.5, 0.5, 0.8)

	if _selected_cards.size() == 3:
		_check_selection()
		_reset_selection_visuals()
		_selected_cards.clear()

func _check_selection() -> void:
	var cards: Array = []
	for index in _selected_cards:
		cards.append(_board_cards[index])
	if SetRules.is_set(cards):
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		_score += _correct_answer_points(_count_set_combinations())
		_refill_cards()
	else:
		if _uses_difficulty_scoring():
			_score = max(0, _score - int(_scoring.get("wrong_penalty", 75)))
		_combo = 0
	score_changed.emit(_score, _combo)

func _correct_answer_points(remaining_answers: int) -> int:
	if not _uses_difficulty_scoring():
		return 100 + _legacy_combo_bonus()
	return _difficulty_points(remaining_answers) + _combo_bonus()

func _difficulty_points(remaining_answers: int) -> int:
	if remaining_answers <= 1:
		return int(_scoring.get("one_answer_points", 300))
	if remaining_answers <= 3:
		return int(_scoring.get("two_to_three_points", 200))
	if remaining_answers <= 5:
		return int(_scoring.get("four_to_five_points", 125))
	return int(_scoring.get("many_answers_points", 75))

func _combo_bonus() -> int:
	if _combo >= 11:
		return 150
	if _combo >= 8:
		return 100
	if _combo >= 5:
		return 60
	if _combo >= 3:
		return 30
	return 0

func _legacy_combo_bonus() -> int:
	if _combo >= 10:
		return 100
	if _combo >= 7:
		return 60
	if _combo >= 4:
		return 30
	return 0

func _refill_cards() -> void:
	for index in _selected_cards:
		_full_deck.append(_board_cards[index])
		_full_deck.shuffle()
		var new_card: Dictionary = _full_deck.pop_back()
		_board_cards[index] = new_card
		_set_card_icon(index, new_card)
	_ensure_answer_available()

func _uses_difficulty_scoring() -> bool:
	return bool(_scoring.get("difficulty_scoring", false))

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

func _ensure_answer_available() -> void:
	if _count_set_combinations() > 0:
		return
	var all_cards: Array[Dictionary] = []
	all_cards.append_array(_board_cards)
	all_cards.append_array(_full_deck)
	all_cards.shuffle()
	_board_cards.clear()
	_full_deck.clear()
	for index in _grid.get_child_count():
		var card_data: Dictionary = all_cards.pop_back()
		_board_cards.append(card_data)
		_set_card_icon(index, card_data)
	_full_deck = all_cards

func _set_card_icon(index: int, card_data: Dictionary) -> void:
	var card_button := _grid.get_child(index) as Button
	card_button.icon = load(CardCatalog.texture_path_for(card_data))

func _reset_selection_visuals() -> void:
	for index in _selected_cards:
		(_grid.get_child(index) as Button).modulate = Color.WHITE

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
		"mode": _mode_id,
		"score": _score,
		"combo": _max_combo
	})
