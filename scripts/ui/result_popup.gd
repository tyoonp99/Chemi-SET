class_name ResultPopup
extends ColorRect

signal restart_pressed
signal title_pressed
signal high_score_submitted(player_name: String)

const RANKING_ROW_LABEL := preload("res://resources/styles/rankings/ranking_row_label.tres")
const RANKING_CURRENT_ROW_LABEL := preload("res://resources/styles/rankings/ranking_current_row_label.tres")
const RANK_ACHIEVEMENT_GOLD := preload("res://resources/styles/rankings/rank_achievement_gold_label.tres")
const RANK_ACHIEVEMENT_SILVER := preload("res://resources/styles/rankings/rank_achievement_silver_label.tres")
const RANK_ACHIEVEMENT_BRONZE := preload("res://resources/styles/rankings/rank_achievement_bronze_label.tres")
const RANK_ACHIEVEMENT_STANDARD := preload("res://resources/styles/rankings/rank_achievement_standard_label.tres")

var _active_result_mode: StringName = &""
var _ranking_entry_pending := false

@onready var _result_label: Label = %ResultLabel
@onready var _speed_result_content: VBoxContainer = %SpeedResultContent
@onready var _rank_achievement_label: Label = %RankAchievementLabel
@onready var _score_value: Label = %ScoreValue
@onready var _excellent_count_value: Label = %ExcellentCountValue
@onready var _great_count_value: Label = %GreatCountValue
@onready var _good_count_value: Label = %GoodCountValue
@onready var _max_combo_value: Label = %MaxComboValue
@onready var _wrong_count_value: Label = %WrongCountValue
@onready var _gyulhap_result_content: VBoxContainer = %GyulHapResultContent
@onready var _gyulhap_rank_achievement_label: Label = %GyulHapRankAchievementLabel
@onready var _gyulhap_score_value: Label = %GyulHapScoreValue
@onready var _hap_success_value: Label = %HapSuccessValue
@onready var _gyul_success_value: Label = %GyulSuccessValue
@onready var _hap_wrong_value: Label = %HapWrongValue
@onready var _hap_duplicate_value: Label = %HapDuplicateValue
@onready var _gyul_fail_value: Label = %GyulFailValue
@onready var _rank_entry_content: VBoxContainer = %RankEntryContent
@onready var _rank_name_input: LineEdit = %RankNameInput
@onready var _rank_submit_button: Button = %RankSubmitButton
@onready var _ranking_content: VBoxContainer = %RankingContent
@onready var _ranking_title_label: Label = %RankingTitleLabel
@onready var _ranking_empty_label: Label = %RankingEmptyLabel
@onready var _ranking_rows: GridContainer = %RankingRows
@onready var _result_actions: VBoxContainer = %ResultActions
@onready var _restart_button: Button = %RestartButton
@onready var _top_scores_button: Button = %TopScoresButton
@onready var _title_button: Button = %TitleButton
@onready var _back_to_result_button: Button = %BackToResultButton

func _ready() -> void:
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	_top_scores_button.pressed.connect(_show_rankings)
	_title_button.pressed.connect(func() -> void: title_pressed.emit())
	_back_to_result_button.pressed.connect(_show_active_summary)
	_rank_submit_button.pressed.connect(_submit_high_score)
	_rank_name_input.text_submitted.connect(func(_text: String) -> void: _submit_high_score())

func show_result(message: String) -> void:
	_active_result_mode = &""
	_ranking_entry_pending = false
	_speed_result_content.hide()
	_gyulhap_result_content.hide()
	_rank_entry_content.hide()
	_ranking_content.hide()
	_result_label.show()
	_result_actions.show()
	_top_scores_button.hide()
	_result_label.text = message
	show()

func show_speed_result(result: Dictionary, rankings: Array) -> void:
	_active_result_mode = Global.MODE_SPEED
	_result_label.hide()
	_score_value.text = "%d점" % int(result.get("score", 0))
	_excellent_count_value.text = "%d회" % int(result.get("excellent_count", 0))
	_great_count_value.text = "%d회" % int(result.get("great_count", 0))
	_good_count_value.text = "%d회" % int(result.get("good_count", 0))
	_max_combo_value.text = "%d COMBO" % int(result.get("combo", 0))
	_wrong_count_value.text = "%d회" % int(result.get("wrong_count", 0))
	_ranking_title_label.text = "⚡ 급속 실험 TOP 5"
	_configure_ranking_state(result)
	_set_rank_achievement(_rank_achievement_label, int(result.get("rank_achieved", 0)))
	_render_rankings(rankings, _highlight_rank(result))
	_show_active_summary()
	show()

func show_gyulhap_result(result: Dictionary, rankings: Array) -> void:
	_active_result_mode = Global.MODE_GYULHAP
	_result_label.hide()
	_gyulhap_score_value.text = "%d점" % int(result.get("score", 0))
	_hap_success_value.text = "%d회" % int(result.get("hap_success_count", 0))
	_gyul_success_value.text = "%d회" % int(result.get("gyul_success_count", 0))
	_hap_wrong_value.text = "%d회" % int(result.get("hap_wrong_count", 0))
	_hap_duplicate_value.text = "%d회" % int(result.get("hap_duplicate_count", 0))
	_gyul_fail_value.text = "%d회" % int(result.get("gyul_fail_count", 0))
	_ranking_title_label.text = "⏱ 정밀 실험 TOP 5"
	_configure_ranking_state(result)
	_set_rank_achievement(_gyulhap_rank_achievement_label, int(result.get("rank_achieved", 0)))
	_render_rankings(rankings, _highlight_rank(result))
	_show_active_summary()
	show()

func _configure_ranking_state(result: Dictionary) -> void:
	_ranking_entry_pending = bool(result.get("ranking_entry_pending", false))
	if _ranking_entry_pending:
		_rank_name_input.clear()
		_rank_submit_button.disabled = false

func _highlight_rank(result: Dictionary) -> int:
	if not bool(result.get("ranking_registered", false)):
		return 0
	return int(result.get("rank_achieved", 0))

func _show_active_summary() -> void:
	_speed_result_content.visible = _active_result_mode == Global.MODE_SPEED
	_gyulhap_result_content.visible = _active_result_mode == Global.MODE_GYULHAP
	_rank_entry_content.visible = _ranking_entry_pending
	_ranking_content.hide()
	_result_actions.visible = not _ranking_entry_pending
	_top_scores_button.show()
	if _ranking_entry_pending:
		_rank_name_input.grab_focus()

func _show_rankings() -> void:
	_speed_result_content.hide()
	_gyulhap_result_content.hide()
	_rank_entry_content.hide()
	_ranking_content.show()
	_result_actions.hide()

func _submit_high_score() -> void:
	if not _ranking_entry_pending:
		return
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9]")
	var player_name := regex.sub(_rank_name_input.text, "", true).strip_edges().to_upper().left(3)
	if player_name.is_empty():
		player_name = "P1"
	_ranking_entry_pending = false
	_rank_submit_button.disabled = true
	high_score_submitted.emit(player_name)

func _set_rank_achievement(label: Label, achieved_rank: int) -> void:
	label.visible = achieved_rank in range(1, Global.RANKING_LIMIT + 1)
	if not label.visible:
		return
	match achieved_rank:
		1:
			label.label_settings = RANK_ACHIEVEMENT_GOLD
			label.text = "🥇 1위 달성!"
		2:
			label.label_settings = RANK_ACHIEVEMENT_SILVER
			label.text = "🥈 2위 달성!"
		3:
			label.label_settings = RANK_ACHIEVEMENT_BRONZE
			label.text = "🥉 3위 달성!"
		_:
			label.label_settings = RANK_ACHIEVEMENT_STANDARD
			label.text = "%d위 달성!" % achieved_rank

func _render_rankings(rankings: Array, highlight_rank: int) -> void:
	for child in _ranking_rows.get_children():
		_ranking_rows.remove_child(child)
		child.queue_free()

	_ranking_empty_label.visible = rankings.is_empty()
	_ranking_rows.visible = not rankings.is_empty()
	for index in min(rankings.size(), Global.RANKING_LIMIT):
		var record: Dictionary = rankings[index]
		var row_settings := RANKING_CURRENT_ROW_LABEL if index + 1 == highlight_rank else RANKING_ROW_LABEL
		_ranking_rows.add_child(_make_ranking_label(_rank_marker(index), row_settings, HORIZONTAL_ALIGNMENT_CENTER, 64.0))
		var name_label := _make_ranking_label(str(record.get("name", "---")), row_settings, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ranking_rows.add_child(name_label)
		_ranking_rows.add_child(
			_make_ranking_label("%d점" % int(record.get("score", 0)), row_settings, HORIZONTAL_ALIGNMENT_RIGHT, 150.0)
		)

func _make_ranking_label(
	text_value: String,
	settings: LabelSettings,
	alignment: HorizontalAlignment,
	minimum_width: float = 0.0
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.label_settings = settings
	label.horizontal_alignment = alignment
	label.custom_minimum_size.x = minimum_width
	return label

func _rank_marker(index: int) -> String:
	match index:
		0:
			return "🥇"
		1:
			return "🥈"
		2:
			return "🥉"
		_:
			return str(index + 1)
