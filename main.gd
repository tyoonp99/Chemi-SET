extends Control

const SPEED_SCENE := preload("res://mode_speed.tscn")
const GYULHAP_SCENE := preload("res://mode_gyulhap.tscn")

var _current_mode: Node
var _current_config: Dictionary = {}
var _current_result: Dictionary = {}

@onready var _ui: UIManager = %GameUI
@onready var _mode_host: Control = %ModeHost

func _ready() -> void:
	_ui.pause_requested.connect(_on_pause_requested)
	_ui.resume_requested.connect(_on_resume_requested)
	_ui.restart_requested.connect(_load_selected_mode)
	_ui.title_requested.connect(_return_to_title)
	_ui.high_score_submitted.connect(_on_high_score_submitted)
	_load_selected_mode()

func _load_selected_mode() -> void:
	get_tree().paused = false
	_ui.hide_all_popups()
	if _current_mode:
		_mode_host.remove_child(_current_mode)
		_current_mode.queue_free()

	_current_config = Global.get_mode_config()
	match Global.selected_mode:
		Global.MODE_SPEED:
			_current_config["mode_id"] = Global.MODE_SPEED
			_current_mode = SPEED_SCENE.instantiate()
		Global.MODE_GYULHAP:
			_current_config["mode_id"] = Global.MODE_GYULHAP
			_current_mode = GYULHAP_SCENE.instantiate()
		_:
			push_warning("Requested mode is not implemented yet; loading Speed mode.")
			_current_config["mode_id"] = Global.MODE_SPEED
			_current_mode = SPEED_SCENE.instantiate()
	_mode_host.add_child(_current_mode)
	_current_mode.connect(&"score_changed", _on_score_changed)
	_current_mode.connect(&"time_changed", _on_time_changed)
	_current_mode.connect(&"game_over", _on_game_over)
	_current_mode.call("start", _current_config)

func _on_score_changed(score: int, _combo: int) -> void:
	_ui.set_score(score)

func _on_time_changed(seconds_left: int, unlimited: bool) -> void:
	_ui.set_time(seconds_left, unlimited)

func _on_game_over(result: Dictionary) -> void:
	_current_result = result.duplicate(true)
	var mode: StringName = StringName(_current_result["mode"])
	if bool(_current_config.get("ranking_enabled", true)) and Global.check_high_score(int(_current_result["score"]), mode):
		_ui.show_high_score_entry()
	else:
		_show_result()

func _on_high_score_submitted(player_name: String) -> void:
	Global.add_high_score(
		StringName(_current_result["mode"]),
		player_name,
		int(_current_result["score"]),
		int(_current_result["combo"])
	)
	_ui.hide_high_score_entry()
	_show_result()

func _show_result() -> void:
	var mode: StringName = StringName(_current_result["mode"])
	var rankings := Global.get_rankings_for_mode(mode)
	var board_text := "🏆 HIGH SCORES 🏆\n\n"
	for index in range(Global.RANKING_LIMIT):
		if index < rankings.size():
			var record: Dictionary = rankings[index]
			board_text += "%d위  %s   %d점\n" % [index + 1, record["name"], record["score"]]
		else:
			board_text += "%d위  ---   0점\n" % [index + 1]
	board_text += "\n내 점수: %d점\n최대 콤보: %d" % [_current_result["score"], _current_result["combo"]]
	_ui.show_result(board_text)

func _on_pause_requested() -> void:
	_ui.show_pause()
	get_tree().paused = true

func _on_resume_requested() -> void:
	_ui.hide_pause()
	get_tree().paused = false

func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://title.tscn")
