extends ColorRect

const RANKING_ROW_LABEL := preload("res://resources/styles/rankings/ranking_row_label.tres")

@onready var _speed_tab: Button = %SpeedRankingTab
@onready var _precision_tab: Button = %PrecisionRankingTab
@onready var _mode_title: Label = %RankingModeTitle
@onready var _empty_label: Label = %RankingEmptyLabel
@onready var _rows: GridContainer = %RankingRows
@onready var _close_button: Button = %RankingCloseButton

func _ready() -> void:
	_speed_tab.pressed.connect(func() -> void: _show_mode(Global.MODE_SPEED))
	_precision_tab.pressed.connect(func() -> void: _show_mode(Global.MODE_GYULHAP))
	_close_button.pressed.connect(hide)

func open_mode(mode: StringName = Global.MODE_SPEED) -> void:
	_show_mode(mode)
	show()

func _show_mode(mode: StringName) -> void:
	var selected_mode := Global.MODE_GYULHAP if mode == Global.MODE_GYULHAP else Global.MODE_SPEED
	_speed_tab.button_pressed = selected_mode == Global.MODE_SPEED
	_precision_tab.button_pressed = selected_mode == Global.MODE_GYULHAP
	_mode_title.text = "⚡ 급속 실험" if selected_mode == Global.MODE_SPEED else "⏱ 정밀 실험"
	_render_rankings(Global.get_rankings_for_mode(selected_mode))

func _render_rankings(rankings: Array) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	_empty_label.visible = rankings.is_empty()
	_rows.visible = not rankings.is_empty()
	for index in min(rankings.size(), Global.RANKING_LIMIT):
		var record: Dictionary = rankings[index]
		_rows.add_child(_make_label(_rank_marker(index), HORIZONTAL_ALIGNMENT_CENTER, 64.0))
		var name_label := _make_label(str(record.get("name", "---")), HORIZONTAL_ALIGNMENT_LEFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(name_label)
		_rows.add_child(_make_label("%d점" % int(record.get("score", 0)), HORIZONTAL_ALIGNMENT_RIGHT, 150.0))

func _make_label(text_value: String, alignment: HorizontalAlignment, minimum_width: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text_value
	label.label_settings = RANKING_ROW_LABEL
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
