class_name GameHud
extends Control

signal pause_pressed

const FEEDBACK_EXCELLENT := preload("res://feedback_excellent_label.tres")
const FEEDBACK_EXCELLENT_SCORE := preload("res://feedback_excellent_score_label.tres")
const FEEDBACK_NICE := preload("res://feedback_nice_label.tres")
const FEEDBACK_NICE_SCORE := preload("res://feedback_nice_score_label.tres")
const FEEDBACK_GOOD := preload("res://feedback_good_label.tres")
const FEEDBACK_GOOD_SCORE := preload("res://feedback_good_score_label.tres")
const FEEDBACK_COMBO := preload("res://feedback_combo_label.tres")
const FEEDBACK_GYUL := preload("res://feedback_gyul_label.tres")
const FEEDBACK_MISS := preload("res://feedback_miss_label.tres")

@onready var _score_value: Label = %ScoreValueLabel
@onready var _time_value: Label = %TimeValueLabel
@onready var _score_title: Label = %ScoreTitleLabel
@onready var _time_title: Label = %TimeTitleLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _score_box: VBoxContainer = %ScoreBox

var _displayed_score := 0
var _score_tween: Tween
var _shake_tween: Tween
var _hud_rest_position := Vector2.ZERO
var _is_practice_display := false

func _ready() -> void:
	_hud_rest_position = position
	_settings_button.pressed.connect(func() -> void: pause_pressed.emit())

func set_score(score: int, _combo: int) -> void:
	if _is_practice_display:
		return
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	if score == _displayed_score:
		_set_score_text(score)
	else:
		_score_tween = create_tween()
		_score_tween.set_trans(Tween.TRANS_QUAD)
		_score_tween.set_ease(Tween.EASE_OUT)
		_score_tween.tween_method(_set_score_text, _displayed_score, score, 0.5)

func set_time(seconds_left: int, unlimited: bool) -> void:
	if _is_practice_display:
		return
	if unlimited:
		_time_value.text = "무제한"
		return
	var minutes := floori(float(seconds_left) / 60.0)
	_time_value.text = "%d:%02d" % [minutes, seconds_left % 60]

func configure_for_mode(mode: StringName) -> void:
	_is_practice_display = mode == Global.MODE_PRACTICE
	_score_box.visible = true
	if _is_practice_display:
		_score_title.text = "합"
		_time_title.text = "결"
		_score_value.text = "0"
		_time_value.text = "0"
		return
	_score_title.text = "점수"
	_time_title.text = "시간"

func set_practice_stats(hap_count: int, gyul_count: int) -> void:
	if not _is_practice_display:
		return
	_score_value.text = str(hap_count)
	_time_value.text = str(gyul_count)

func show_feedback(message: String, positive: bool, style: String = "nice", breakdown: Dictionary = {}) -> void:
	if positive and not breakdown.is_empty():
		_show_score_breakdown(style, breakdown)
		return
	_show_single_feedback(message, positive, style)

func _show_score_breakdown(style: String, breakdown: Dictionary) -> void:
	var judgment := _make_feedback_line(str(breakdown.get("judgment", style.to_upper())) + "!", _judgment_settings(style))
	var score_line := _make_feedback_line("+ %d" % int(breakdown.get("base_points", 0)), _score_settings(style))
	var lines: Array[Label] = [judgment, score_line]
	var combo := int(breakdown.get("combo", 0))
	if combo > 1:
		var combo_bonus := int(breakdown.get("combo_bonus", 0))
		var combo_text := "%d COMBO!" % combo
		if combo_bonus > 0:
			combo_text += " (+%d)" % combo_bonus
		var combo_line := _make_feedback_line(combo_text, FEEDBACK_COMBO)
		lines.append(combo_line)

	for index in lines.size():
		_show_cascading_line(lines[index], 270.0 + index * 78.0, index * 0.13, style)

func _make_feedback_line(text: String, settings: LabelSettings) -> Label:
	var line := Label.new()
	line.text = text
	line.custom_minimum_size = Vector2(600, 72)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.label_settings = settings
	line.pivot_offset = Vector2(300, 36)
	line.scale = Vector2(0.45, 0.45)
	line.modulate.a = 0.0
	return line

func _show_cascading_line(line: Label, start_y: float, delay: float, style: String) -> void:
	add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	line.offset_left = -300.0
	line.offset_right = 300.0
	line.offset_top = start_y
	line.offset_bottom = start_y + 72.0
	var pop_scale := 1.13 if style == "excellent" else 1.09 if style == "nice" else 1.06
	var float_distance := 60.0 if style == "excellent" else 46.0
	var pop_tween := line.create_tween()
	pop_tween.tween_interval(delay)
	pop_tween.set_trans(Tween.TRANS_BACK)
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(line, "scale", Vector2(pop_scale, pop_scale), 0.1)
	pop_tween.parallel().tween_property(line, "modulate:a", 1.0, 0.05)
	pop_tween.tween_property(line, "scale", Vector2.ONE, 0.14)
	pop_tween.tween_property(line, "offset_top", start_y - float_distance, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop_tween.parallel().tween_property(line, "offset_bottom", start_y + 72.0 - float_distance, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	pop_tween.parallel().tween_property(line, "modulate:a", 0.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	pop_tween.tween_callback(line.queue_free)

func _show_single_feedback(message: String, positive: bool, style: String) -> void:
	var floating_label := _make_feedback_line(message, _single_feedback_settings(style, positive))
	add_child(floating_label)
	floating_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	floating_label.offset_left = -300.0
	floating_label.offset_right = 300.0
	floating_label.offset_top = 300.0
	floating_label.offset_bottom = 372.0
	floating_label.scale = Vector2(0.82, 0.82)
	floating_label.modulate.a = 1.0

	var tween := floating_label.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(floating_label, "scale", Vector2(1.16, 1.16), 0.12)
	tween.tween_property(floating_label, "scale", Vector2.ONE, 0.14)
	tween.parallel().tween_property(floating_label, "offset_top", 245.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(floating_label, "offset_bottom", 317.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(floating_label, "modulate:a", 0.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(floating_label.queue_free)
	if style == "miss":
		_shake_hud()

func _set_score_text(value: float) -> void:
	_displayed_score = roundi(value)
	_score_value.text = str(_displayed_score)

func _judgment_settings(style: String) -> LabelSettings:
	match style:
		"excellent":
			return FEEDBACK_EXCELLENT
		"nice":
			return FEEDBACK_NICE
		_:
			return FEEDBACK_GOOD

func _score_settings(style: String) -> LabelSettings:
	match style:
		"excellent":
			return FEEDBACK_EXCELLENT_SCORE
		"nice":
			return FEEDBACK_NICE_SCORE
		_:
			return FEEDBACK_GOOD_SCORE

func _single_feedback_settings(style: String, positive: bool) -> LabelSettings:
	if not positive or style == "miss":
		return FEEDBACK_MISS
	if style == "gyul":
		return FEEDBACK_GYUL
	return _judgment_settings(style)

func _shake_hud() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	position = _hud_rest_position
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position:x", _hud_rest_position.x + 12.0, 0.05)
	_shake_tween.tween_property(self, "position:x", _hud_rest_position.x - 12.0, 0.08)
	_shake_tween.tween_property(self, "position:x", _hud_rest_position.x + 6.0, 0.06)
	_shake_tween.tween_property(self, "position:x", _hud_rest_position.x, 0.05)
