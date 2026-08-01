extends Control

func _ready():
	# 1. 모드 선택 버튼 연결
	%Btn1Min.pressed.connect(_on_btn_1min_pressed)
	%Btn3Min.pressed.connect(_on_btn_3min_pressed)
	%BtnPractice.pressed.connect(_on_btn_practice_pressed)
	
	# 2. 기타 UI 버튼 연결
	%QuitButton.pressed.connect(_on_quit_button_pressed) # 위치가 바뀌어도 % 덕분에 정상 작동함!
	%TutorialButton.pressed.connect(_on_tutorial_button_pressed)
	%TutorialCloseButton.pressed.connect(_on_close_button_pressed)
	
	# 3. 랭킹 버튼 및 랭킹 닫기 버튼 연결
	%RankingButton.pressed.connect(_on_ranking_button_pressed)
	%RankingCloseButton.pressed.connect(_on_ranking_close_button_pressed)
	
	# 💡 [추가됨] 설정 닫기 버튼 연결 (에디터에서 연결 안 했다면 추가)
	%SettingsCloseButton.pressed.connect(_on_settings_close_button_pressed)
	
	# 시작할 때 팝업들은 숨겨둡니다
	%TutorialPopup.hide()
	%RankingPopup.hide()
	%SettingsPopup.hide() # 💡 [추가됨] 설정 팝업도 처음에 숨기기

# --- 모드 선택 로직 ---
func _on_btn_1min_pressed():
	_start_speed_mode(60, true, {
		"difficulty_scoring": true,
		"one_answer_points": 300,
		"two_to_three_points": 200,
		"four_to_five_points": 125,
		"many_answers_points": 75,
		"wrong_penalty": 75
	})

func _on_btn_3min_pressed():
	Global.configure_mode(Global.MODE_GYULHAP, {
		"time_limit": 180,
		"ranking_enabled": true,
		"hap_points": 100,
		"gyul_points": 400,
		"wrong_hap_penalty": 75,
		"wrong_gyul_penalty": 200
	})
	get_tree().change_scene_to_file("res://main.tscn")

func _on_btn_practice_pressed():
	# Practice 전용 씬이 추가되기 전까지는 Speed 규칙을 무제한·비랭킹으로 제공한다.
	_start_speed_mode(0, false)

func _start_speed_mode(time_limit: int, ranking_enabled: bool, scoring: Dictionary = {}) -> void:
	Global.configure_mode(Global.MODE_SPEED, {
		"time_limit": time_limit,
		"ranking_enabled": ranking_enabled,
		"scoring": scoring
	})
	get_tree().change_scene_to_file("res://main.tscn")

# --- 부가 기능 로직 (튜토리얼, 종료) ---
func _on_tutorial_button_pressed():
	%TutorialPopup.show()

func _on_close_button_pressed():
	%TutorialPopup.hide()

func _on_quit_button_pressed():
	get_tree().quit()

# --- 🏆 랭킹 팝업 로직 ---
func _on_ranking_button_pressed():
	var board_text = "🏆 HIGH SCORES 🏆\n\n"
	
	var rankings := Global.get_rankings_for_mode(Global.MODE_SPEED)
	for index in range(1, 6):
		if index <= rankings.size():
			var r = rankings[index - 1]
			board_text += str(index) + "위  " + r["name"] + "   " + str(int(r["score"])) + "점\n"
		else:
			board_text += str(index) + "위  ---   0점\n"
			
	# 세팅한 글씨를 라벨에 밀어넣고 팝업 띄우기
	%RankingLabel.text = board_text
	%RankingPopup.show()

func _on_ranking_close_button_pressed():
	%RankingPopup.hide()

# --- ⚙️ 설정 팝업 로직 [추가됨] ---
func _on_setting_button_pressed() -> void:
	%SettingsPopup.show()

func _on_settings_close_button_pressed() -> void:
	%SettingsPopup.hide()
