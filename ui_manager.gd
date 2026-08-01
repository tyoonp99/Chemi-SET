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
var _high_score_popup: HighScorePopup

func _ready() -> void:
	for component in get_children():
		if component is GameHud:
			_hud = component
		elif component is PausePopup:
			_pause_popup = component
		elif component is ResultPopup:
			_result_popup = component
		elif component is HighScorePopup:
			_high_score_popup = component

	if _hud:
		_hud.pause_pressed.connect(func() -> void: pause_requested.emit())
	if _pause_popup:
		_pause_popup.resume_pressed.connect(func() -> void: resume_requested.emit())
		_pause_popup.restart_pressed.connect(func() -> void: restart_requested.emit())
		_pause_popup.title_pressed.connect(func() -> void: title_requested.emit())
	if _result_popup:
		_result_popup.restart_pressed.connect(func() -> void: restart_requested.emit())
		_result_popup.title_pressed.connect(func() -> void: title_requested.emit())
	if _high_score_popup:
		_high_score_popup.submitted.connect(func(player_name: String) -> void: high_score_submitted.emit(player_name))

	hide_all_popups()

func set_score(score: int, combo: int = 0) -> void:
	if _hud:
		_hud.set_score(score, combo)

func set_time(seconds_left: int, unlimited: bool = false) -> void:
	if _hud:
		_hud.set_time(seconds_left, unlimited)

func configure_for_mode(is_practice: bool) -> void:
	if _hud:
		_hud.configure_for_mode(is_practice)

func show_feedback(message: String, positive: bool) -> void:
	if _hud:
		_hud.show_feedback(message, positive)

func show_pause() -> void:
	if _pause_popup:
		_pause_popup.show()

func hide_pause() -> void:
	if _pause_popup:
		_pause_popup.hide()

func show_result(message: String) -> void:
	if _result_popup:
		_result_popup.show_result(message)

func show_high_score_entry() -> void:
	if _high_score_popup:
		_high_score_popup.show_entry()

func hide_high_score_entry() -> void:
	if _high_score_popup:
		_high_score_popup.hide()

func hide_all_popups() -> void:
	if _pause_popup:
		_pause_popup.hide()
	if _result_popup:
		_result_popup.hide()
	if _high_score_popup:
		_high_score_popup.hide()
