class_name ModeGyulHap
extends Control

signal score_changed(score: int, combo: int)
signal time_changed(seconds_left: int, unlimited: bool)
signal game_over(result: Dictionary)
signal feedback_changed(message: String, positive: bool, style: String)
signal practice_stats_changed(
	hap_count: int,
	gyul_count: int,
	session_hap_count: int,
	session_gyul_count: int
)
signal telemetry_event(event_name: StringName, data: Dictionary)

const ACTION_INPUT_LOCK_MS := 120

var _selected_cards: Array[int] = []
var _full_deck: Array[Dictionary] = []
var _board_cards: Array[Dictionary] = []
var _found_hap_keys: Dictionary = {}
var _found_hap_order: Array[String] = []
var _hinted_hap_keys: Dictionary = {}
var _score := 0
var _combo := 0
var _max_combo := 0
var _hap_success_count := 0
var _hap_wrong_count := 0
var _hap_duplicate_count := 0
var _gyul_success_count := 0
var _gyul_fail_count := 0
var _is_game_over := false
var _last_time := -1
var _config: Dictionary = {}
var _mode_id: StringName = Global.MODE_GYULHAP
var _is_practice := false
var _is_board_transition := false
var _session_hap_count := 0
var _session_gyul_count := 0
var _practice_start_hap_count := 0
var _practice_start_gyul_count := 0
var _hint_used_this_round := false
var _board_revision := 0
var _active_hint_card_index := -1
var _session_started_at_ms := 0
var _board_started_at_ms := 0
var _active_hint_started_at_ms := 0
var _card_press_tweens: Array[Tween] = []
var _input_locked_until_ms := 0

@onready var _grid: GridContainer = %GridContainer
@onready var _timer: Timer = %Timer
@onready var _hap_button: Button = %HapButton
@onready var _gyul_button: Button = %GyulButton
@onready var _hint_button: Button = %HintButton
@onready var _hap_history: PracticeHapHistory = %PracticeHapHistory
@onready var _round_hap_count_label: Label = %RoundHapCountLabel

func _ready() -> void:
	SoundManager.bind_clicks_in(self)
	_card_press_tweens.resize(_grid.get_child_count())
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
	_hap_success_count = 0
	_hap_wrong_count = 0
	_hap_duplicate_count = 0
	_gyul_success_count = 0
	_gyul_fail_count = 0
	_is_game_over = false
	_is_board_transition = false
	_session_started_at_ms = Time.get_ticks_msec()
	var saved_stats := Global.get_infinite_stats()
	_session_hap_count = int(saved_stats.get("hap", 0))
	_session_gyul_count = int(saved_stats.get("gyul", 0))
	_practice_start_hap_count = _session_hap_count
	_practice_start_gyul_count = _session_gyul_count
	_hint_used_this_round = false
	_last_time = -1
	_input_locked_until_ms = 0
	_redeal_board()
	_telemetry(&"session_started", {
		"time_limit_seconds": int(_config.get("time_limit", 180)),
		"practice_mode": _is_practice
	})
	var time_limit := int(_config.get("time_limit", 180))
	if time_limit <= 0:
		_timer.stop()
	else:
		_timer.wait_time = time_limit
		_timer.start()
	score_changed.emit(_score, _combo)
	if _is_practice:
		_emit_practice_stats()
	_emit_time()

func _process(_delta: float) -> void:
	if not _is_game_over and not _is_practice:
		_emit_time()

func _on_card_pressed(index: int) -> void:
	if _is_game_over or _is_board_transition or _is_input_locked():
		return
	var card_button := _grid.get_child(index) as Button
	_play_card_press_tension(index)
	if index in _selected_cards:
		_selected_cards.erase(index)
		card_button.modulate = Color.WHITE
	elif _selected_cards.size() < 3:
		_selected_cards.append(index)
		card_button.modulate = Color(0.5, 0.5, 0.5, 0.8)
	_update_action_buttons()

func _on_hap_pressed() -> void:
	if _selected_cards.size() != 3 or _is_game_over or _is_board_transition or _is_input_locked():
		return
	var selected_data: Array = []
	for index in _selected_cards:
		selected_data.append(_board_cards[index])
	var attempt_data := {
		"board_revision": _board_revision,
		"elapsed_board_ms": _elapsed_board_ms(),
		"elapsed_session_ms": _elapsed_session_ms(),
		"selected_indices": _selected_cards.duplicate(),
		"found_hap_count_before": _found_hap_keys.size(),
		"total_hap_count": _count_set_combinations()
	}
	if SetRules.is_set(selected_data):
		var hap_key := _selected_hap_key()
		if not _found_hap_keys.has(hap_key):
			_hap_success_count += 1
			_found_hap_keys[hap_key] = true
			_found_hap_order.append(hap_key)
			var used_active_hint := _is_practice and _active_hint_card_index in _selected_cards
			if used_active_hint:
				_hinted_hap_keys[hap_key] = true
				attempt_data["hint_to_solution_ms"] = max(0, Time.get_ticks_msec() - _active_hint_started_at_ms)
				_set_hint_marker(_active_hint_card_index, false)
				_active_hint_card_index = -1
			_combo += 1
			_max_combo = max(_max_combo, _combo)
			var earned_points := int(_config.get("hap_points", 100))
			if not _is_practice:
				_score += earned_points
				feedback_changed.emit("합성 성공! +%d점" % earned_points, true, "nice")
			else:
				if not _hinted_hap_keys.has(hap_key):
					Global.add_infinite_stats(1, 0)
					_session_hap_count += 1
				feedback_changed.emit("합성 성공", true, "good")
				_emit_practice_stats()
			SoundManager.play_synthesis_success()
			HapticManager.play_synthesis_success()
			attempt_data["result"] = "found"
			attempt_data["used_hint"] = used_active_hint
			attempt_data["found_hap_count_after"] = _found_hap_keys.size()
			attempt_data["score_after"] = _score
			_telemetry(&"hap_attempt", attempt_data)
			_update_hap_history()
			_update_round_hap_count()
		else:
			_hap_duplicate_count += 1
			var duplicate_penalty := int(_config.get("wrong_hap_penalty", 75))
			_apply_penalty(duplicate_penalty)
			attempt_data["result"] = "duplicate"
			attempt_data["penalty"] = 0 if _is_practice else duplicate_penalty
			attempt_data["score_after"] = _score
			_telemetry(&"hap_attempt", attempt_data)
			feedback_changed.emit(
				"이미 합성한 조합입니다" if _is_practice else "이미 합성한 조합입니다. -%d점" % duplicate_penalty,
				false,
				"miss"
			)
			SoundManager.play_failure()
			HapticManager.play_synthesis_failure()
		_clear_selection()
	else:
		_hap_wrong_count += 1
		var penalty := int(_config.get("wrong_hap_penalty", 75))
		_apply_penalty(penalty)
		attempt_data["result"] = "wrong"
		attempt_data["penalty"] = 0 if _is_practice else penalty
		attempt_data["score_after"] = _score
		_telemetry(&"hap_attempt", attempt_data)
		feedback_changed.emit("합성 실패" if _is_practice else "합성 실패! -%d점" % penalty, false, "miss")
		SoundManager.play_failure()
		HapticManager.play_synthesis_failure()
		_clear_selection()
	score_changed.emit(_score, _combo)
	_lock_action_input()

func _on_gyul_pressed() -> void:
	if _is_game_over or _is_board_transition or _is_input_locked():
		return
	var total_hap_count := _count_set_combinations()
	var gyul_data := {
		"board_revision": _board_revision,
		"elapsed_board_ms": _elapsed_board_ms(),
		"elapsed_session_ms": _elapsed_session_ms(),
		"found_hap_count": _found_hap_keys.size(),
		"total_hap_count": total_hap_count,
		"hint_used_this_round": _hint_used_this_round
	}
	if _found_hap_keys.size() == total_hap_count:
		_gyul_success_count += 1
		_is_board_transition = true
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		var earned_points := int(_config.get("gyul_points", 400))
		if not _is_practice:
			_score += earned_points
			feedback_changed.emit("완료 성공! +%d점" % earned_points, true, "gyul")
		else:
			if not _hint_used_this_round:
				Global.add_infinite_stats(0, 1)
				_session_gyul_count += 1
			feedback_changed.emit("완료 성공! 새 보드를 준비합니다", true, "gyul")
			_emit_practice_stats()
		SoundManager.play_completion_success()
		HapticManager.play_completion_success()
		gyul_data["success"] = true
		gyul_data["score_after"] = _score
		gyul_data["elapsed_board_ms"] = _elapsed_board_ms()
		_telemetry(&"gyul_attempt", gyul_data)
		_telemetry(&"board_completed", gyul_data)
		_redeal_board()
		score_changed.emit(_score, _combo)
		await get_tree().create_timer(0.2).timeout
		_is_board_transition = false
		_update_action_buttons()
		return
	else:
		_gyul_fail_count += 1
		var penalty := int(_config.get("wrong_gyul_penalty", 200))
		_apply_penalty(penalty)
		gyul_data["success"] = false
		gyul_data["penalty"] = 0 if _is_practice else penalty
		gyul_data["score_after"] = _score
		_telemetry(&"gyul_attempt", gyul_data)
		feedback_changed.emit("완료 실패" if _is_practice else "완료 실패! -%d점" % penalty, false, "miss")
		SoundManager.play_failure()
		_clear_selection()
	score_changed.emit(_score, _combo)
	_lock_action_input()

func _on_hint_pressed() -> void:
	if not _is_practice or _is_game_over or _is_board_transition or _is_input_locked():
		return
	if _active_hint_card_index != -1:
		return
	if _remaining_unfound_hap_count() == 0:
		_hint_used_this_round = true
		_telemetry(&"hint_used", {
			"board_revision": _board_revision,
			"elapsed_board_ms": _elapsed_board_ms(),
			"hint_type": "gyul_check",
			"remaining_hap_count": 0
		})
		feedback_changed.emit("모든 합성을 찾았습니다! 완료를 눌러주세요.", true, "gyul")
		_pulse_gyul_button()
		return
	var hint_target := _find_hint_target()
	if hint_target.is_empty():
		feedback_changed.emit("힌트를 준비할 수 없습니다", false, "miss")
		return
	_hint_used_this_round = true
	var card_index: int = hint_target.pick_random()
	_active_hint_card_index = card_index
	_active_hint_started_at_ms = Time.get_ticks_msec()
	_telemetry(&"hint_used", {
		"board_revision": _board_revision,
		"elapsed_board_ms": _elapsed_board_ms(),
		"hint_type": "card",
		"card_index": card_index,
		"remaining_hap_count": _remaining_unfound_hap_count()
	})
	var card_button := _grid.get_child(card_index) as Button
	_set_hint_marker(card_index, true)
	var hint_tween := card_button.create_tween()
	hint_tween.set_trans(Tween.TRANS_BACK)
	hint_tween.set_ease(Tween.EASE_OUT)
	hint_tween.tween_property(card_button, "scale", Vector2(1.12, 1.12), 0.14)
	hint_tween.tween_property(card_button, "scale", Vector2.ONE, 0.2)
	feedback_changed.emit("합성 힌트", true, "nice")
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
	_hap_history.visible = true
	_round_hap_count_label.visible = not _is_practice
	_hint_button.visible = _is_practice
	_update_hap_history()
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
	_begin_board_log()

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

func _is_input_locked() -> bool:
	return Time.get_ticks_msec() < _input_locked_until_ms

func _lock_action_input() -> void:
	_input_locked_until_ms = Time.get_ticks_msec() + ACTION_INPUT_LOCK_MS

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

func _set_hint_marker(index: int, should_show: bool) -> void:
	if index < 0 or index >= _grid.get_child_count():
		return
	var card_button := _grid.get_child(index) as Button
	(card_button.get_node("HintMarker") as Control).visible = should_show

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

func _update_hap_history() -> void:
	_hap_history.set_haps(_found_hap_order)

func _update_round_hap_count() -> void:
	if _is_practice:
		return
	_round_hap_count_label.text = "이번 보드 합성: %d개" % _found_hap_keys.size()

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

func _play_card_press_tension(index: int) -> void:
	var card_button := _grid.get_child(index) as Button
	var previous_tween := _card_press_tweens[index]
	if previous_tween and previous_tween.is_valid():
		previous_tween.kill()
	card_button.pivot_offset = card_button.size * 0.5
	card_button.scale = Vector2.ONE
	var press_tween := card_button.create_tween()
	press_tween.set_trans(Tween.TRANS_QUAD)
	press_tween.set_ease(Tween.EASE_OUT)
	press_tween.tween_property(card_button, "scale", Vector2(0.96, 0.96), 0.045)
	press_tween.tween_property(card_button, "scale", Vector2.ONE, 0.10)
	_card_press_tweens[index] = press_tween

func _emit_practice_stats() -> void:
	if not _is_practice:
		return
	practice_stats_changed.emit(
		_session_hap_count,
		_session_gyul_count,
		max(0, _session_hap_count - _practice_start_hap_count),
		max(0, _session_gyul_count - _practice_start_gyul_count)
	)

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
	_telemetry(&"session_finished", {
		"elapsed_session_ms": _elapsed_session_ms(),
		"score": _score,
		"max_combo": _max_combo,
		"hap_success_count": _hap_success_count,
		"hap_wrong_count": _hap_wrong_count,
		"hap_duplicate_count": _hap_duplicate_count,
		"gyul_success_count": _gyul_success_count,
		"gyul_fail_count": _gyul_fail_count,
		"board_revisions": _board_revision
	})
	time_changed.emit(0, false)
	game_over.emit({
		"mode": _mode_id,
		"score": _score,
		"combo": _max_combo,
		"hap_success_count": _hap_success_count,
		"hap_wrong_count": _hap_wrong_count,
		"hap_duplicate_count": _hap_duplicate_count,
		"gyul_success_count": _gyul_success_count,
		"gyul_fail_count": _gyul_fail_count
	})

func _begin_board_log() -> void:
	_board_started_at_ms = Time.get_ticks_msec()
	_telemetry(&"board_started", {
		"board_revision": _board_revision,
		"cards": _board_snapshot(),
		"difficulty": _board_difficulty(),
		"practice_mode": _is_practice
	})

func _telemetry(event_name: StringName, data: Dictionary) -> void:
	telemetry_event.emit(event_name, data)

func _elapsed_session_ms() -> int:
	return max(0, Time.get_ticks_msec() - _session_started_at_ms)

func _elapsed_board_ms() -> int:
	return max(0, Time.get_ticks_msec() - _board_started_at_ms)

func _board_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for card in _board_cards:
		snapshot.append({
			"shape": int(card.get("shape", -1)),
			"color": int(card.get("color", -1)),
			"state": int(card.get("state", -1))
		})
	return snapshot

func _board_difficulty() -> Dictionary:
	var appearances: Array[int] = []
	appearances.resize(_board_cards.size())
	appearances.fill(0)
	var set_count := 0
	for first_index in range(_board_cards.size() - 2):
		for second_index in range(first_index + 1, _board_cards.size() - 1):
			for third_index in range(second_index + 1, _board_cards.size()):
				if SetRules.is_set([_board_cards[first_index], _board_cards[second_index], _board_cards[third_index]]):
					set_count += 1
					appearances[first_index] += 1
					appearances[second_index] += 1
					appearances[third_index] += 1
	var shared_cards := 0
	var max_overlap := 0
	for count in appearances:
		if count > 1:
			shared_cards += 1
		max_overlap = max(max_overlap, count)
	return {
		"set_count": set_count,
		"shared_card_count": shared_cards,
		"max_card_overlap": max_overlap
	}
