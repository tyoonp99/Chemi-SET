class_name ModeSpeed
extends Control

signal score_changed(score: int, combo: int)
signal time_changed(seconds_left: int, unlimited: bool)
signal game_over(result: Dictionary)
signal feedback_changed(message: String, positive: bool, style: String, breakdown: Dictionary)
signal telemetry_event(event_name: StringName, data: Dictionary)

const LOW_ANSWER_LIMIT := 2
const RECOVERY_MIN_SET_COUNT := 3
const RECOVERY_GENERATION_ATTEMPTS := 20
const INITIAL_GENERATION_ATTEMPTS := 20

var _selected_cards: Array[int] = []
var _full_deck: Array[Dictionary] = []
var _board_cards: Array[Dictionary] = []
var _score := 0
var _combo := 0
var _max_combo := 0
var _correct_count := 0
var _wrong_count := 0
var _excellent_count := 0
var _great_count := 0
var _good_count := 0
var _is_game_over := false
var _is_unlimited := false
var _last_time := -1
var _mode_id: StringName = Global.MODE_SPEED
var _scoring: Dictionary = {}
var _session_started_at_ms := 0
var _board_started_at_ms := 0
var _board_revision := 0
var _previous_board_had_low_answers := false
var _card_press_tweens: Array[Tween] = []

@onready var _grid: GridContainer = %GridContainer
@onready var _timer: Timer = %Timer

func _ready() -> void:
	SoundManager.bind_clicks_in(self)
	_card_press_tweens.resize(_grid.get_child_count())
	for index in _grid.get_child_count():
		var card_button := _grid.get_child(index) as Button
		card_button.pressed.connect(_on_card_pressed.bind(index))
	_timer.timeout.connect(_on_timer_timeout)

func start(config: Dictionary) -> void:
	_mode_id = StringName(config.get("mode_id", Global.MODE_SPEED))
	_is_unlimited = int(config.get("time_limit", 60)) <= 0
	var scoring_config: Variant = config.get("scoring", {})
	_scoring = scoring_config.duplicate(true) if scoring_config is Dictionary else {}
	_session_started_at_ms = Time.get_ticks_msec()
	_build_board()
	_telemetry(&"session_started", {
		"time_limit_seconds": int(config.get("time_limit", 60)),
		"difficulty_scoring": _uses_difficulty_scoring(),
		"score_rule_version": int(_scoring.get("score_rule_version", 1))
	})
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
	_score = 0
	_combo = 0
	_max_combo = 0
	_correct_count = 0
	_wrong_count = 0
	_excellent_count = 0
	_great_count = 0
	_good_count = 0
	_is_game_over = false
	_last_time = -1
	var initial_attempts := _deal_initial_board_with_minimum_sets()
	_previous_board_had_low_answers = _count_set_combinations() <= LOW_ANSWER_LIMIT
	_begin_board_log(&"initial", {
		"recovery_required": false,
		"candidate_attempts": initial_attempts,
		"target_met": _count_set_combinations() >= RECOVERY_MIN_SET_COUNT
	})

func _deal_initial_board_with_minimum_sets() -> int:
	var attempts := 0
	while attempts < INITIAL_GENERATION_ATTEMPTS:
		attempts += 1
		if not _board_cards.is_empty():
			_full_deck.append_array(_board_cards)
			_board_cards.clear()
		_full_deck.shuffle()
		for index in _grid.get_child_count():
			var card_data: Dictionary = _full_deck.pop_back()
			_board_cards.append(card_data)
			_set_card_icon(index, card_data)
		if _count_set_combinations() >= RECOVERY_MIN_SET_COUNT:
			return attempts

	_deal_guaranteed_initial_board()
	return attempts + 1

func _deal_guaranteed_initial_board() -> void:
	var candidate_pool: Array[Dictionary] = _full_deck.duplicate()
	candidate_pool.append_array(_board_cards)
	candidate_pool.shuffle()
	var guaranteed_cards: Array[Dictionary] = []
	for _set_number in 3:
		var set_cards := _find_set_in_cards(candidate_pool)
		if set_cards.is_empty():
			break
		for card in set_cards:
			guaranteed_cards.append(card)
			candidate_pool.erase(card)
	while guaranteed_cards.size() < _grid.get_child_count():
		guaranteed_cards.append(candidate_pool.pop_back())
	_board_cards = guaranteed_cards
	_full_deck = candidate_pool
	for index in _grid.get_child_count():
		_set_card_icon(index, _board_cards[index])

func _find_set_in_cards(cards: Array[Dictionary]) -> Array[Dictionary]:
	for first_index in range(cards.size() - 2):
		for second_index in range(first_index + 1, cards.size() - 1):
			for third_index in range(second_index + 1, cards.size()):
				var set_cards := [cards[first_index], cards[second_index], cards[third_index]]
				if SetRules.is_set(set_cards):
					return set_cards
	return []

func _on_card_pressed(index: int) -> void:
	if _is_game_over:
		return
	var card_button := _grid.get_child(index) as Button
	_play_card_press_tension(index)
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
	var answer_count_before := _count_set_combinations()
	var attempt_data := {
		"board_revision": _board_revision,
		"elapsed_board_ms": _elapsed_board_ms(),
		"elapsed_session_ms": _elapsed_session_ms(),
		"selected_indices": _selected_cards.duplicate(),
		"answer_count_before": answer_count_before,
		"score_rule_version": int(_scoring.get("score_rule_version", 1))
	}
	if SetRules.is_set(cards):
		_correct_count += 1
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		var remaining_answers := _count_set_combinations()
		var breakdown := _score_breakdown(remaining_answers)
		var earned_points := int(breakdown["base_points"]) + int(breakdown["combo_bonus"])
		_score += earned_points
		var feedback_style := _feedback_style_for(remaining_answers)
		_increment_judgment_count(feedback_style)
		breakdown["judgment"] = feedback_style.to_upper()
		breakdown["combo"] = _combo
		attempt_data["success"] = true
		attempt_data["judgment"] = feedback_style
		attempt_data["base_points"] = int(breakdown["base_points"])
		attempt_data["set_pattern"] = String(_set_pattern(cards))
		attempt_data["combo_bonus"] = int(breakdown["combo_bonus"])
		attempt_data["earned_points"] = earned_points
		attempt_data["combo"] = _combo
		attempt_data["score_after"] = _score
		_telemetry(&"hap_attempt", attempt_data)
		feedback_changed.emit("%s! +%d점" % [feedback_style.to_upper(), earned_points], true, feedback_style, breakdown)
		SoundManager.play_synthesis_success()
		HapticManager.play_synthesis_success()
		_refill_cards()
	else:
		_wrong_count += 1
		var penalty := 0
		if _uses_difficulty_scoring():
			penalty = int(_scoring.get("wrong_penalty", 75))
			_score = max(0, _score - penalty)
		_combo = 0
		attempt_data["success"] = false
		attempt_data["penalty"] = penalty
		attempt_data["score_after"] = _score
		_telemetry(&"hap_attempt", attempt_data)
		feedback_changed.emit("MISS! -%d점" % penalty if penalty > 0 else "MISS!", false, "miss", {})
		SoundManager.play_failure()
		HapticManager.play_synthesis_failure()
	score_changed.emit(_score, _combo)

func _score_breakdown(remaining_answers: int) -> Dictionary:
	if not _uses_difficulty_scoring():
		return {
			"base_points": 100,
			"combo_bonus": _legacy_combo_bonus()
		}
	return {
		"base_points": _difficulty_points(remaining_answers),
		"combo_bonus": _combo_bonus()
	}

func _set_pattern(cards: Array) -> StringName:
	var shape_different := _attribute_is_all_different(cards, &"shape")
	var color_different := _attribute_is_all_different(cards, &"color")
	var state_different := _attribute_is_all_different(cards, &"state")
	if shape_different and color_different and state_different:
		return &"all_different"
	if shape_different and color_different and not state_different:
		return &"shape_color_different_state_same"
	return &"standard"

func _attribute_is_all_different(cards: Array, attribute: StringName) -> bool:
	var values: Dictionary = {}
	for card in cards:
		if not card is Dictionary:
			return false
		values[int(card.get(String(attribute), -1))] = true
	return values.size() == 3

func _difficulty_points(remaining_answers: int) -> int:
	if remaining_answers <= 1:
		return int(_scoring.get("one_answer_points", 300))
	if remaining_answers == 2:
		return int(_scoring.get("two_answer_points", 240))
	if remaining_answers <= 4:
		return int(_scoring.get("three_to_four_points", 120))
	return int(_scoring.get("five_or_more_points", 80))

func _feedback_style_for(remaining_answers: int) -> String:
	if remaining_answers <= 1:
		return "excellent"
	if remaining_answers == 2:
		return "great"
	return "good"

func _increment_judgment_count(feedback_style: String) -> void:
	match feedback_style:
		"excellent":
			_excellent_count += 1
		"great":
			_great_count += 1
		_:
			_good_count += 1

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
	var generation := _replace_selected_cards(_previous_board_had_low_answers)
	_ensure_answer_available()
	var new_set_count := _count_set_combinations()
	generation["resulting_set_count"] = new_set_count
	generation["target_met"] = not bool(generation["recovery_required"]) or new_set_count >= RECOVERY_MIN_SET_COUNT
	_previous_board_had_low_answers = new_set_count <= LOW_ANSWER_LIMIT
	_begin_board_log(&"refill", generation)

func _replace_selected_cards(recovery_required: bool) -> Dictionary:
	var candidate_pool: Array[Dictionary] = _full_deck.duplicate()
	for index in _selected_cards:
		candidate_pool.append(_board_cards[index])
	var attempts := RECOVERY_GENERATION_ATTEMPTS
	var best_replacements: Array[Dictionary] = []
	var best_set_count := -1
	var attempts_used := 0
	for _attempt in attempts:
		attempts_used += 1
		var shuffled_pool: Array[Dictionary] = candidate_pool.duplicate()
		shuffled_pool.shuffle()
		var candidate_cards: Array[Dictionary] = _board_cards.duplicate()
		var replacements: Array[Dictionary] = []
		for index in _selected_cards:
			var replacement: Dictionary = shuffled_pool.pop_back()
			candidate_cards[index] = replacement
			replacements.append(replacement)
		if SetRules.is_set(replacements):
			continue
		var candidate_set_count := _count_set_combinations_for(candidate_cards)
		if candidate_set_count <= 0:
			continue
		if candidate_set_count > best_set_count:
			best_set_count = candidate_set_count
			best_replacements = replacements
		if not recovery_required or candidate_set_count >= RECOVERY_MIN_SET_COUNT:
			break
	if best_replacements.is_empty():
		best_replacements = _find_non_set_replacements(candidate_pool)
		var fallback_cards: Array[Dictionary] = _board_cards.duplicate()
		for replacement_index in _selected_cards.size():
			fallback_cards[_selected_cards[replacement_index]] = best_replacements[replacement_index]
		best_set_count = _count_set_combinations_for(fallback_cards)

	_full_deck = candidate_pool
	for replacement in best_replacements:
		_full_deck.erase(replacement)
	for replacement_index in _selected_cards.size():
		var card_index := _selected_cards[replacement_index]
		var new_card := best_replacements[replacement_index]
		_board_cards[card_index] = new_card
		_set_card_icon(card_index, new_card)
	return {
		"recovery_required": recovery_required,
		"candidate_attempts": attempts_used,
		"candidate_set_count": best_set_count,
		"replacement_cards_form_set": SetRules.is_set(best_replacements),
		"target_met": not recovery_required or best_set_count >= RECOVERY_MIN_SET_COUNT
	}

func _find_non_set_replacements(cards: Array[Dictionary]) -> Array[Dictionary]:
	for first_index in range(cards.size() - 2):
		for second_index in range(first_index + 1, cards.size() - 1):
			for third_index in range(second_index + 1, cards.size()):
				var replacements := [cards[first_index], cards[second_index], cards[third_index]]
				if not SetRules.is_set(replacements):
					return replacements
	return []

func _uses_difficulty_scoring() -> bool:
	return bool(_scoring.get("difficulty_scoring", false))

func _count_set_combinations() -> int:
	return _count_set_combinations_for(_board_cards)

func _count_set_combinations_for(cards: Array[Dictionary]) -> int:
	var count := 0
	for first_index in range(cards.size() - 2):
		for second_index in range(first_index + 1, cards.size() - 1):
			for third_index in range(second_index + 1, cards.size()):
				if SetRules.is_set([
					cards[first_index],
					cards[second_index],
					cards[third_index]
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
	_telemetry(&"session_finished", {
		"elapsed_session_ms": _elapsed_session_ms(),
		"score": _score,
		"max_combo": _max_combo,
		"correct_count": _correct_count,
		"wrong_count": _wrong_count,
		"excellent_count": _excellent_count,
		"great_count": _great_count,
		"good_count": _good_count,
		"board_revisions": _board_revision
	})
	time_changed.emit(0, false)
	game_over.emit({
		"mode": _mode_id,
		"score": _score,
		"combo": _max_combo,
		"correct_count": _correct_count,
		"wrong_count": _wrong_count,
		"excellent_count": _excellent_count,
		"great_count": _great_count,
		"good_count": _good_count
	})

func _begin_board_log(reason: StringName, generation: Dictionary = {}) -> void:
	_board_revision += 1
	_board_started_at_ms = Time.get_ticks_msec()
	var board_data := {
		"board_revision": _board_revision,
		"reason": String(reason),
		"cards": _board_snapshot(),
		"difficulty": _board_difficulty()
	}
	if not generation.is_empty():
		board_data["generation"] = generation.duplicate(true)
	_telemetry(&"board_started", board_data)

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
