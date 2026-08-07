extends Control

var _pending_mode_start: Callable

func _ready():
	SoundManager.bind_clicks_in(self)
	# 1. 모드 선택 버튼 연결
	%Btn1Min.pressed.connect(_on_btn_1min_pressed)
	%Btn3Min.pressed.connect(_on_btn_3min_pressed)
	%BtnPractice.pressed.connect(_on_btn_practice_pressed)
	
	# 2. 기타 UI 버튼 연결
	%QuitButton.pressed.connect(_on_quit_button_pressed) # 위치가 바뀌어도 % 덕분에 정상 작동함!
	%TutorialButton.pressed.connect(_on_tutorial_button_pressed)
	%TutorialPopup.interactive_tutorial_requested.connect(_on_interactive_tutorial_requested)
	%InteractiveTutorial.completed.connect(_on_interactive_tutorial_completed)
	
	# 3. 랭킹 버튼 연결
	%RankingButton.pressed.connect(_on_speed_ranking_pressed)
	
	# 💡 [추가됨] 설정 닫기 버튼 연결 (에디터에서 연결 안 했다면 추가)
	%SettingsCloseButton.pressed.connect(_on_settings_close_button_pressed)
	
	# 시작할 때 팝업들은 숨겨둡니다
	%TutorialPopup.hide()
	%RankingPopup.hide()
	%SettingsPopup.hide() # 💡 [추가됨] 설정 팝업도 처음에 숨기기

# --- 모드 선택 로직 ---
func _on_btn_1min_pressed():
	_request_mode_start(func() -> void: _start_speed_mode(60, true, {
		"difficulty_scoring": true,
		"score_rule_version": 4,
		"one_answer_points": 300,
		"two_answer_points": 240,
		"three_to_four_points": 120,
		"five_or_more_points": 80,
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
	%TutorialPopup.call("open")

func _on_interactive_tutorial_requested() -> void:
	_pending_mode_start = Callable()
	%InteractiveTutorial.call("open")

func _request_mode_start(start_action: Callable) -> void:
	if Global.has_completed_tutorial():
		start_action.call()
		return
	_pending_mode_start = start_action
	%InteractiveTutorial.call("open")

func _on_interactive_tutorial_completed() -> void:
	if _pending_mode_start.is_valid():
		var start_action := _pending_mode_start
		_pending_mode_start = Callable()
		start_action.call()

func _on_quit_button_pressed():
	get_tree().quit()

func _on_speed_ranking_pressed() -> void:
	%RankingPopup.call("open_mode", Global.MODE_SPEED)

# --- ⚙️ 설정 팝업 로직 [추가됨] ---
func _on_setting_button_pressed() -> void:
	%SettingsPopup.show()

func _on_settings_close_button_pressed() -> void:
	%SettingsPopup.hide()
