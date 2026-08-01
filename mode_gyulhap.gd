class_name ModeGyulHap
extends Control

signal score_changed(score: int, combo: int)
signal time_changed(seconds_left: int, unlimited: bool)
signal game_over(result: Dictionary)
signal feedback_changed(message: String, positive: bool)

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
var _mode_id: StringName = Global.MODE_GYULHAP
var _is_practice := false

@onready var _grid: GridContainer = %GridContainer
@onready var _timer: Timer = %Timer
@onready var _selection_label: Label = %SelectionLabel
@onready var _hap_button: Button = %HapButton
@onready var _gyul_button: Button = %GyulButton
@onready var _found_haps_label: Label = %FoundHapsLabel

func _ready() -> void:
	for index in _grid.get_child_count():
		(_grid.get_child(index) as Button).pressed.connect(_on_card_pressed.bind(index))
	_hap_button.pressed.connect(_on_hap_pressed)
	_gyul_button.pressed.connect(_on_gyul_pressed)
	_timer.timeout.connect(_on_timer_timeout)

func start(config: Dictionary) -> void:
	_config = config.duplicate(true)
	_mode_id = StringName(_config.get("mode_id", Global.MODE_GYULHAP))
	_is_practice = bool(_config.get("practice_mode", false))
	_score = 0
	_combo = 0
	_max_combo = 0
	_is_game_over = false
	_last_time = -1
	_redeal_board()
	var time_limit := int(_config.get("time_limit", 180))
	if time_limit <= 0:
		_timer.stop()
	else:
		_timer.wait_time = time_limit
		_timer.start()
	score_changed.emit(_score, _combo)
	_emit_time()

func _process(_delta: float) -> void:
	if not _is_game_over and not _is_practice:
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
			var earned_points := int(_config.get("hap_points", 100))
			if not _is_practice:
				_score += earned_points
				feedback_changed.emit("합 성공! +%d점" % earned_points, true)
			else:
				feedback_changed.emit("합을 찾았습니다", true)
			_update_found_haps_ui()
		else:
			var duplicate_penalty := int(_config.get("wrong_hap_penalty", 75))
			_apply_penalty(duplicate_penalty)
			feedback_changed.emit(
				"이미 진행한 합입니다" if _is_practice else "이미 진행한 합입니다. -%d점" % duplicate_penalty,
				false
			)
		_clear_selection()
	else:
		var penalty := int(_config.get("wrong_hap_penalty", 75))
		_apply_penalty(penalty)
		feedback_changed.emit("합 실패" if _is_practice else "합 실패! -%d점" % penalty, false)
		_clear_selection()
	score_changed.emit(_score, _combo)

func _on_gyul_pressed() -> void:
	if _is_game_over:
		return
	if _found_hap_keys.size() == _count_set_combinations():
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		var earned_points := int(_config.get("gyul_points", 400))
		if not _is_practice:
			_score += earned_points
			feedback_changed.emit("결 성공! +%d점" % earned_points, true)
		else:
			feedback_changed.emit("결 성공! 새 보드를 준비합니다", true)
		_redeal_board()
	else:
		var penalty := int(_config.get("wrong_gyul_penalty", 200))
		_apply_penalty(penalty)
		feedback_changed.emit("결 실패" if _is_practice else "결 실패! -%d점" % penalty, false)
		_clear_selection()
	score_changed.emit(_score, _combo)

func _apply_penalty(points: int) -> void:
	if _is_practice:
		return
	_score = max(0, _score - points)
	_combo = 0

func _redeal_board() -> void:
	_selected_cards.clear()
	_found_hap_keys.clear()
	_found_haps_label.visible = _is_practice
	_update_found_haps_ui()
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

func _update_found_haps_ui() -> void:
	if not _is_practice:
		return
	if _found_hap_keys.is_empty():
		_found_haps_label.text = "찾은 합: 아직 없습니다"
		return
	var entries: PackedStringArray = []
	var hap_keys: Array = _found_hap_keys.keys()
	hap_keys.sort()
	for hap_key in hap_keys:
		var indices: PackedStringArray = String(hap_key).split("-")
		entries.append("%d·%d·%d" % [int(indices[0]) + 1, int(indices[1]) + 1, int(indices[2]) + 1])
	_found_haps_label.text = "찾은 합 (%d): %s" % [_found_hap_keys.size(), "  |  ".join(entries)]

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
	if _is_practice:
		time_changed.emit(0, true)
		return
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
