class_name UIManager
extends CanvasLayer

signal pause_requested
signal resume_requested
signal restart_requested
signal title_requested
signal high_score_submitted(player_name: String)

var _hud: GameHud
var _pause_popup: PausePopup
var _result_popup: ResultPopup

func _ready() -> void:
	SoundManager.bind_clicks_in(self)
	for component in get_children():
		if component is GameHud:
			_hud = component
		elif component is PausePopup:
			_pause_popup = component
		elif component is ResultPopup:
			_result_popup = component

	if _hud:
		_hud.pause_pressed.connect(func() -> void: pause_requested.emit())
	if _pause_popup:
		_pause_popup.resume_pressed.connect(func() -> void: resume_requested.emit())
		_pause_popup.restart_pressed.connect(func() -> void: restart_requested.emit())
		_pause_popup.title_pressed.connect(func() -> void: title_requested.emit())
	if _result_popup:
		_result_popup.restart_pressed.connect(func() -> void: restart_requested.emit())
		_result_popup.title_pressed.connect(func() -> void: title_requested.emit())
		_result_popup.high_score_submitted.connect(
			func(player_name: String) -> void: high_score_submitted.emit(player_name)
		)

	hide_all_popups()

func set_score(score: int, combo: int = 0) -> void:
	if _hud:
		_hud.set_score(score, combo)

func set_time(seconds_left: int, unlimited: bool = false) -> void:
	if _hud:
		_hud.set_time(seconds_left, unlimited)

func configure_for_mode(mode: StringName) -> void:
	if _hud:
		_hud.configure_for_mode(mode)

func set_practice_stats(
	hap_count: int,
	gyul_count: int,
	session_hap_count: int,
	session_gyul_count: int
) -> void:
	if _hud:
		_hud.set_practice_stats(hap_count, gyul_count, session_hap_count, session_gyul_count)

func show_feedback(message: String, positive: bool, style: String = "nice", breakdown: Dictionary = {}) -> void:
	if _hud:
		_hud.show_feedback(message, positive, style, breakdown)

func show_pause() -> void:
	if _pause_popup:
		_pause_popup.show()

func hide_pause() -> void:
	if _pause_popup:
		_pause_popup.hide()

func show_result(message: String) -> void:
	if _result_popup:
		_result_popup.show_result(message)

func show_speed_result(result: Dictionary, rankings: Array) -> void:
	if _result_popup:
		_result_popup.show_speed_result(result, rankings)

func show_gyulhap_result(result: Dictionary, rankings: Array) -> void:
	if _result_popup:
		_result_popup.show_gyulhap_result(result, rankings)

func hide_all_popups() -> void:
	if _pause_popup:
		_pause_popup.hide()
	if _result_popup:
		_result_popup.hide()
