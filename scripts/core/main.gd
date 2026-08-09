extends Control

const SPEED_SCENE := preload("res://scenes/modes/mode_speed.tscn")
const GYULHAP_SCENE := preload("res://scenes/modes/mode_gyulhap.tscn")

enum GameFlowState {
    PLAYING,
    PAUSE_POPUP,
    RESULT_POPUP
}

var _current_mode: Node
var _current_config: Dictionary = {}
var _current_result: Dictionary = {}
var _session_active := false
var _flow_state := GameFlowState.PLAYING

@onready var _ui: UIManager = %GameUI
@onready var _mode_host: Control = %ModeHost

func _ready() -> void:
    get_tree().set_auto_accept_quit(false)
    _ui.pause_requested.connect(_on_pause_requested)
    _ui.resume_requested.connect(_on_resume_requested)
    _ui.restart_requested.connect(_load_selected_mode)
    _ui.title_requested.connect(_return_to_title)
    _ui.high_score_submitted.connect(_on_high_score_submitted)
    _load_selected_mode()

func _load_selected_mode() -> void:
    get_tree().paused = false
    _ui.hide_all_popups()
    _current_result.clear()
    _session_active = true
    _flow_state = GameFlowState.PLAYING
    if _current_mode:
        _mode_host.remove_child(_current_mode)
        _current_mode.queue_free()

    _current_config = Global.get_mode_config()
    match Global.selected_mode:
        Global.MODE_SPEED:
            _current_config["mode_id"] = Global.MODE_SPEED
            _current_mode = SPEED_SCENE.instantiate()
        Global.MODE_GYULHAP, Global.MODE_PRACTICE:
            _current_config["mode_id"] = Global.MODE_GYULHAP
            if Global.selected_mode == Global.MODE_PRACTICE:
                _current_config["mode_id"] = Global.MODE_PRACTICE
            _current_mode = GYULHAP_SCENE.instantiate()
        _:
            push_warning("Requested mode is not implemented yet; loading Speed mode.")
            _current_config["mode_id"] = Global.MODE_SPEED
            _current_mode = SPEED_SCENE.instantiate()
    _mode_host.add_child(_current_mode)
    _current_mode.connect(&"score_changed", _on_score_changed)
    _current_mode.connect(&"time_changed", _on_time_changed)
    _current_mode.connect(&"game_over", _on_game_over)
    if _current_mode.has_signal(&"feedback_changed"):
        _current_mode.connect(&"feedback_changed", _on_feedback_changed)
    if _current_mode.has_signal(&"practice_stats_changed"):
        _current_mode.connect(&"practice_stats_changed", _on_practice_stats_changed)
    if _current_mode.has_signal(&"telemetry_event"):
        _current_mode.connect(&"telemetry_event", _on_telemetry_event)
    _ui.configure_for_mode(Global.selected_mode)
    _current_mode.call("start", _current_config)

func _on_score_changed(score: int, combo: int) -> void:
    _ui.set_score(score, combo)

func _on_time_changed(seconds_left: int, unlimited: bool) -> void:
    _ui.set_time(seconds_left, unlimited)

func _on_feedback_changed(message: String, positive: bool, style: String = "nice", breakdown: Dictionary = {}) -> void:
    _ui.show_feedback(message, positive, style, breakdown)

func _on_practice_stats_changed(
    hap_count: int,
    gyul_count: int,
    session_hap_count: int,
    session_gyul_count: int
) -> void:
    _ui.set_practice_stats(hap_count, gyul_count, session_hap_count, session_gyul_count)

func _on_telemetry_event(event_name: StringName, data: Dictionary) -> void:
    PlaytestLogger.log_event(Global.selected_mode, event_name, data)

func _on_game_over(result: Dictionary) -> void:
    _session_active = false
    _flow_state = GameFlowState.RESULT_POPUP
    _current_result = result.duplicate(true)
    var mode: StringName = StringName(_current_result["mode"])
    var ranking_enabled := bool(_current_config.get("ranking_enabled", true))
    if ranking_enabled and Global.check_high_score(int(_current_result["score"]), mode):
        _current_result["rank_achieved"] = _calculate_rank(mode, int(_current_result["score"]))
        _current_result["ranking_entry_pending"] = true
    _show_result()

func _on_high_score_submitted(player_name: String) -> void:
    if not bool(_current_result.get("ranking_entry_pending", false)):
        return
    var mode := StringName(_current_result["mode"])
    Global.add_high_score(
        mode,
        player_name,
        int(_current_result["score"]),
        int(_current_result["combo"])
    )
    _current_result["ranking_entry_pending"] = false
    _current_result["ranking_registered"] = true
    _current_result["registered_name"] = player_name
    _show_result()

func _calculate_rank(mode: StringName, score: int) -> int:
    var rank := 1
    for ranking_record in Global.get_rankings_for_mode(mode):
        var record: Dictionary = ranking_record
        if int(record.get("score", 0)) > score:
            rank += 1
    return rank if rank <= Global.RANKING_LIMIT else 0

func _show_result() -> void:
    var mode: StringName = StringName(_current_result["mode"])
    var rankings := Global.get_rankings_for_mode(mode)
    if mode == Global.MODE_SPEED:
        var speed_result := _current_result.duplicate(true)
        _ui.show_speed_result(speed_result, rankings)
        return
    if mode == Global.MODE_GYULHAP:
        var gyulhap_result := _current_result.duplicate(true)
        _ui.show_gyulhap_result(gyulhap_result, rankings)
        return
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
    if _flow_state != GameFlowState.PLAYING:
        return
    _ui.show_pause()
    get_tree().paused = true
    _flow_state = GameFlowState.PAUSE_POPUP

func _on_resume_requested() -> void:
    if _flow_state != GameFlowState.PAUSE_POPUP:
        return
    _ui.hide_pause()
    get_tree().paused = false
    _flow_state = GameFlowState.PLAYING

func _return_to_title() -> void:
    get_tree().paused = false
    _session_active = false
    _flow_state = GameFlowState.RESULT_POPUP
    get_tree().change_scene_to_file("res://scenes/title.tscn")

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _pause_for_lifecycle()

func _pause_for_lifecycle() -> void:
    if not OS.has_feature("mobile"):
        return
    if _flow_state != GameFlowState.PLAYING or not _session_active:
        return
    if Global.selected_mode == Global.MODE_PRACTICE:
        return
    _on_pause_requested()

func _unhandled_key_input(event: InputEvent) -> void:
    if not OS.has_feature("mobile"):
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACK:
        _handle_android_back_request()
        get_viewport().set_input_as_handled()

func _handle_android_back_request() -> void:
    if _flow_state == GameFlowState.PAUSE_POPUP:
        _on_resume_requested()
    elif _flow_state == GameFlowState.RESULT_POPUP:
        if not _ui.request_result_back():
            _return_to_title()
    elif _flow_state == GameFlowState.PLAYING and _session_active:
        _on_pause_requested()
