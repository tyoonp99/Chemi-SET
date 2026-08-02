class_name ModeGyulHap
extends Control

signal score_changed(score: int, combo: int)
signal time_changed(seconds_left: int, unlimited: bool)
signal game_over(result: Dictionary)
signal feedback_changed(message: String, positive: bool, style: String)
signal practice_stats_changed(hap_count: int, gyul_count: int)

var _selected_cards: Array[int] = []
var _full_deck: Array[Dictionary] = []
var _board_cards: Array[Dictionary] = []
var _found_hap_keys: Dictionary = {}
var _found_hap_order: Array[String] = []
var _hinted_hap_keys: Dictionary = {}
var _score := 0
var _combo := 0
var _max_combo := 0
var _is_game_over := false
var _last_time := -1
var _config: Dictionary = {}
var _mode_id: StringName = Global.MODE_GYULHAP
var _is_practice := false
var _is_board_transition := false
var _session_hap_count := 0
var _session_gyul_count := 0
var _hint_used_this_round := false
var _board_revision := 0
var _active_hint_card_index := -1

@onready var _grid: GridContainer = %GridContainer
@onready var _timer: Timer = %Timer
@onready var _hap_button: Button = %HapButton
@onready var _gyul_button: Button = %GyulButton
@onready var _hint_button: Button = %HintButton
@onready var _practice_hap_history: PracticeHapHistory = %PracticeHapHistory
@onready var _round_hap_count_label: Label = %RoundHapCountLabel

func _ready() -> void:
	for index in _grid.get_child_count():
		(_grid.get_child(index) as Button).pressed.connect(_on_card_pressed.bind(index))
	_hap_button.pressed.connect(_on_hap_pressed)
	_gyul_button.pressed.connect(_on_gyul_pressed)
	_hint_button.pressed.connect(_on_hint_pressed)
	_timer.timeout.connect(_on_timer_timeout)

func start(config: Dictionary) -> void:
	_config = config.duplicate(true)
	_mode_id = StringName(_config.get("mode_id", Global.MODE_GYULHAP))
	_is_practice = bool(_config.get("practice_mode", false))
	_score = 0
	_combo = 0
	_max_combo = 0
	_is_game_over = false
	_is_board_transition = false
	var saved_stats := Global.get_infinite_stats()
	_session_hap_count = int(saved_stats.get("hap", 0))
	_session_gyul_count = int(saved_stats.get("gyul", 0))
	_hint_used_this_round = false
	_last_time = -1
	_redeal_board()
	var time_limit := int(_config.get("time_limit", 180))
	if time_limit <= 0:
		_timer.stop()
	else:
		_timer.wait_time = time_limit
		_timer.start()
	score_changed.emit(_score, _combo)
	if _is_practice:
		practice_stats_changed.emit(_session_hap_count, _session_gyul_count)
	_emit_time()

func _process(_delta: float) -> void:
	if not _is_game_over and not _is_practice:
		_emit_time()

func _on_card_pressed(index: int) -> void:
	if _is_game_over or _is_board_transition:
		return
	var card_button := _grid.get_child(index) as Button
	if index in _selected_cards:
		_selected_cards.erase(index)
		card_button.modulate = Color.WHITE
	elif _selected_cards.size() < 3:
		_selected_cards.append(index)
		card_button.modulate = Color(0.5, 0.5, 0.5, 0.8)
	_update_action_buttons()

func _on_hap_pressed() -> void:
	if _selected_cards.size() != 3 or _is_game_over or _is_board_transition:
		return
	var selected_data: Array = []
	for index in _selected_cards:
		selected_data.append(_board_cards[index])
	if SetRules.is_set(selected_data):
		var hap_key := _selected_hap_key()
		if not _found_hap_keys.has(hap_key):
			_found_hap_keys[hap_key] = true
			_found_hap_order.append(hap_key)
			var used_active_hint := _is_practice and _active_hint_card_index in _selected_cards
			if used_active_hint:
				_hinted_hap_keys[hap_key] = true
				_set_hint_marker(_active_hint_card_index, false)
				_active_hint_card_index = -1
			_combo += 1
			_max_combo = max(_max_combo, _combo)
			var earned_points := int(_config.get("hap_points", 100))
			if not _is_practice:
				_score += earned_points
				feedback_changed.emit("합 성공! +%d점" % earned_points, true, "nice")
			else:
				if not _hinted_hap_keys.has(hap_key):
					Global.add_infinite_stats(1, 0)
					_session_hap_count += 1
				feedback_changed.emit("합을 찾았습니다", true, "good")
				practice_stats_changed.emit(_session_hap_count, _session_gyul_count)
			_update_practice_hap_history()
			_update_round_hap_count()
		else:
			var duplicate_penalty := int(_config.get("wrong_hap_penalty", 75))
			_apply_penalty(duplicate_penalty)
			feedback_changed.emit(
				"이미 진행한 합입니다" if _is_practice else "이미 진행한 합입니다. -%d점" % duplicate_penalty,
				false,
				"miss"
			)
		_clear_selection()
	else:
		var penalty := int(_config.get("wrong_hap_penalty", 75))
		_apply_penalty(penalty)
		feedback_changed.emit("합 실패" if _is_practice else "합 실패! -%d점" % penalty, false, "miss")
		_clear_selection()
	score_changed.emit(_score, _combo)

func _on_gyul_pressed() -> void:
	if _is_game_over or _is_board_transition:
		return
	if _found_hap_keys.size() == _count_set_combinations():
		_is_board_transition = true
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		var earned_points := int(_config.get("gyul_points", 400))
		if not _is_practice:
			_score += earned_points
			feedback_changed.emit("결 성공! +%d점" % earned_points, true, "gyul")
		else:
			if not _hint_used_this_round:
				Global.add_infinite_stats(0, 1)
				_session_gyul_count += 1
			feedback_changed.emit("결 성공! 새 보드를 준비합니다", true, "gyul")
			practice_stats_changed.emit(_session_hap_count, _session_gyul_count)
		_redeal_board()
		score_changed.emit(_score, _combo)
		await get_tree().create_timer(0.2).timeout
		_is_board_transition = false
		_update_action_buttons()
		return
	else:
		var penalty := int(_config.get("wrong_gyul_penalty", 200))
		_apply_penalty(penalty)
		feedback_changed.emit("결 실패" if _is_practice else "결 실패! -%d점" % penalty, false, "miss")
		_clear_selection()
	score_changed.emit(_score, _combo)

func _on_hint_pressed() -> void:
	if not _is_practice or _is_game_over or _is_board_transition:
		return
	if _active_hint_card_index != -1:
		return
	if _remaining_unfound_hap_count() == 0:
		_hint_used_this_round = true
		feedback_changed.emit("결입니다! 결 선언하세요.", true, "gyul")
		_pulse_gyul_button()
		return
	var hint_target := _find_hint_target()
	if hint_target.is_empty():
		feedback_changed.emit("힌트를 준비할 수 없습니다", false, "miss")
		return
	_hint_used_this_round = true
	var card_index: int = hint_target.pick_random()
	_active_hint_card_index = card_index
	var card_button := _grid.get_child(card_index) as Button
	_set_hint_marker(card_index, true)
	var hint_tween := card_button.create_tween()
	hint_tween.set_trans(Tween.TRANS_BACK)
	hint_tween.set_ease(Tween.EASE_OUT)
	hint_tween.tween_property(card_button, "scale", Vector2(1.12, 1.12), 0.14)
	hint_tween.tween_property(card_button, "scale", Vector2.ONE, 0.2)
	feedback_changed.emit("합 힌트", true, "nice")
	_update_action_buttons()

func _apply_penalty(points: int) -> void:
	if _is_practice:
		return
	_score = max(0, _score - points)
	_combo = 0

func _redeal_board() -> void:
	_board_revision += 1
	_selected_cards.clear()
	_found_hap_keys.clear()
	_found_hap_order.clear()
	_hinted_hap_keys.clear()
	_hint_used_this_round = false
	_active_hint_card_index = -1
	_practice_hap_history.visible = _is_practice
	_round_hap_count_label.visible = not _is_practice
	_hint_button.visible = _is_practice
	_update_practice_hap_history()
	_update_round_hap_count()
	_full_deck = CardCatalog.create_full_deck()
	_full_deck.shuffle()
	_board_cards.clear()
	for index in _grid.get_child_count():
		var card_data: Dictionary = _full_deck.pop_back()
		_board_cards.append(card_data)
		_set_card_icon(index, card_data)
		(_grid.get_child(index) as Button).modulate = Color.WHITE
		_set_hint_marker(index, false)
	_ensure_hap_available()
	_update_action_buttons()

func _clear_selection() -> void:
	for index in _selected_cards:
		(_grid.get_child(index) as Button).modulate = Color.WHITE
	_selected_cards.clear()
	_update_action_buttons()

func _update_action_buttons() -> void:
	_hap_button.disabled = _is_board_transition or _selected_cards.size() != 3
	_gyul_button.disabled = _is_board_transition
	_hint_button.disabled = (
		not _is_practice
		or _is_board_transition
		or _active_hint_card_index != -1
	)

func _find_hint_target() -> Array[int]:
	var targets: Array[Array] = []
	for first_index in range(_board_cards.size() - 2):
		for second_index in range(first_index + 1, _board_cards.size() - 1):
			for third_index in range(second_index + 1, _board_cards.size()):
				var indices: Array[int] = [first_index, second_index, third_index]
				if not SetRules.is_set([
					_board_cards[first_index],
					_board_cards[second_index],
					_board_cards[third_index]
				]):
					continue
				var hap_key := _hap_key_for_indices(indices)
				if not _found_hap_keys.has(hap_key):
					targets.append(indices)
	var result: Array[int] = []
	if targets.is_empty():
		return result
	var selected_target: Array = targets.pick_random()
	for index in selected_target:
		result.append(int(index))
	return result

func _remaining_unfound_hap_count() -> int:
	return max(0, _count_set_combinations() - _found_hap_keys.size())

func _set_hint_marker(index: int, is_visible: bool) -> void:
	if index < 0 or index >= _grid.get_child_count():
		return
	var card_button := _grid.get_child(index) as Button
	(card_button.get_node("HintMarker") as Control).visible = is_visible

func _pulse_gyul_button() -> void:
	var pulse_tween := _gyul_button.create_tween()
	pulse_tween.set_trans(Tween.TRANS_BACK)
	pulse_tween.set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(_gyul_button, "scale", Vector2(1.08, 1.08), 0.12)
	pulse_tween.tween_property(_gyul_button, "scale", Vector2.ONE, 0.18)

func _ensure_hap_available() -> void:
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

func _update_practice_hap_history() -> void:
	if not _is_practice:
		return
	_practice_hap_history.set_haps(_found_hap_order)

func _update_round_hap_count() -> void:
	if _is_practice:
		return
	_round_hap_count_label.text = "이번 라운드 합: %d개" % _found_hap_keys.size()

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
	return _hap_key_for_indices(_selected_cards)

func _hap_key_for_indices(indices: Array[int]) -> String:
	var sorted_indices: Array[int] = indices.duplicate()
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
