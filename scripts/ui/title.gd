extends Control

var _pending_mode_start: Callable

func _ready():
	get_tree().set_auto_accept_quit(false)
	SoundManager.bind_clicks_in(self)
	# 1. 모드 선택 버튼 연결
	%Btn1Min.pressed.connect(_on_btn_1min_pressed)
	%Btn3Min.pressed.connect(_on_btn_3min_pressed)
	%BtnPractice.pressed.connect(_on_btn_practice_pressed)
	
	# 2. 기타 UI 버튼 연결
	%QuitButton.pressed.connect(_on_quit_button_pressed) # 위치가 바뀌어도 % 덕분에 정상 작동함!
	%TutorialButton.pressed.connect(_on_tutorial_button_pressed)
	%TutorialPopup.interactive_tutorial_requested.connect(_on_interactive_tutorial_requested)
	%TutorialPopup.dismissed.connect(_clear_pending_mode_start)
	%InteractiveTutorial.completed.connect(_on_interactive_tutorial_completed)
	%InteractiveTutorial.dismissed.connect(_clear_pending_mode_start)
	
	# 3. 랭킹 버튼 연결
	%RankingButton.pressed.connect(_on_speed_ranking_pressed)
	
	# 💡 [추가됨] 설정 닫기 버튼 연결 (에디터에서 연결 안 했다면 추가)
	%SettingsCloseButton.pressed.connect(_on_settings_close_button_pressed)
	%SettingsSoundButton.pressed.connect(_on_settings_sound_button_pressed)
	%SettingsHapticButton.pressed.connect(_on_settings_haptic_button_pressed)
	%ExitConfirmPopup.confirmed.connect(get_tree().quit)
	
	# 시작할 때 팝업들은 숨겨둡니다
	%TutorialPopup.hide()
	%RankingPopup.hide()
	%SettingsPopup.hide() # 💡 [추가됨] 설정 팝업도 처음에 숨기기
	%ExitConfirmPopup.hide()
	_update_settings_sound_button()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not OS.has_feature("mobile"):
		get_tree().quit()

# --- 모드 선택 로직 ---
func _on_btn_1min_pressed():
	_request_mode_start(func() -> void: _start_speed_mode(60, true, {
		"difficulty_scoring": true,
		"score_rule_version": 5,
		"one_answer_points": 300,
		"two_answer_points": 180,
		"three_to_four_points": 100,
		"five_or_more_points": 75,
		"wrong_penalty": 75
	}))

func _on_btn_3min_pressed():
	_request_mode_start(func() -> void: _start_gyulhap_mode())

func _start_gyulhap_mode() -> void:
	Global.configure_mode(Global.MODE_GYULHAP, {
		"time_limit": 180,
		"ranking_enabled": true,
		"hap_points": 100,
		"gyul_points": 400,
		"wrong_hap_penalty": 75,
		"wrong_gyul_penalty": 200
	})
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_btn_practice_pressed():
	_request_mode_start(func() -> void: _start_practice_mode())

func _start_practice_mode() -> void:
	Global.configure_mode(Global.MODE_PRACTICE, {
		"mode_id": Global.MODE_PRACTICE,
		"time_limit": 0,
		"ranking_enabled": false,
		"practice_mode": true,
		"hap_points": 0,
		"gyul_points": 0,
		"wrong_hap_penalty": 0,
		"wrong_gyul_penalty": 0
	})
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _start_speed_mode(time_limit: int, ranking_enabled: bool, scoring: Dictionary = {}) -> void:
	Global.configure_mode(Global.MODE_SPEED, {
		"time_limit": time_limit,
		"ranking_enabled": ranking_enabled,
		"scoring": scoring
	})
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# --- 부가 기능 로직 (튜토리얼, 종료) ---
func _on_tutorial_button_pressed():
	_clear_pending_mode_start()
	%TutorialPopup.call("open")

func _on_interactive_tutorial_requested() -> void:
	%InteractiveTutorial.call("open")

func _request_mode_start(start_action: Callable) -> void:
	if Global.has_completed_tutorial():
		start_action.call()
		return
	_pending_mode_start = start_action
	%TutorialPopup.call("open")

func _clear_pending_mode_start() -> void:
	_pending_mode_start = Callable()

func _on_interactive_tutorial_completed() -> void:
	if _pending_mode_start.is_valid():
		var start_action := _pending_mode_start
		_pending_mode_start = Callable()
		start_action.call()

func _on_quit_button_pressed():
	%SettingsPopup.hide()
	%ExitConfirmPopup.show()

func _on_speed_ranking_pressed() -> void:
	%RankingPopup.call("open_mode", Global.MODE_SPEED)

# --- ⚙️ 설정 팝업 로직 [추가됨] ---
func _on_setting_button_pressed() -> void:
	_update_settings_sound_button()
	%SettingsPopup.show()

func _on_settings_close_button_pressed() -> void:
	%SettingsPopup.hide()

func _on_settings_sound_button_pressed() -> void:
	var enabled := not Global.is_sfx_enabled()
	Global.set_sfx_enabled(enabled)
	SoundManager.set_sfx_enabled(enabled)
	_update_settings_sound_button()

func _on_settings_haptic_button_pressed() -> void:
	Global.set_haptics_enabled(not Global.is_haptics_enabled())
	_update_settings_sound_button()

func _update_settings_sound_button() -> void:
	%SettingsSoundButton.text = "🔊 효과음 ON" if Global.is_sfx_enabled() else "🔇 효과음 OFF"
	%SettingsHapticButton.text = "📳 진동 ON" if Global.is_haptics_enabled() else "📴 진동 OFF"

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.has_feature("mobile"):
		return
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACK):
		return
	get_viewport().set_input_as_handled()
	if %ExitConfirmPopup.visible:
		%ExitConfirmPopup.hide()
	elif %SettingsPopup.visible:
		%SettingsPopup.hide()
	elif %RankingPopup.visible:
		%RankingPopup.hide()
	elif %TutorialPopup.visible:
		%TutorialPopup.dismiss()
	elif %InteractiveTutorial.visible:
		%InteractiveTutorial.dismiss()
	else:
		%ExitConfirmPopup.show()
