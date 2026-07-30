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
	Global.game_time = 60
	get_tree().change_scene_to_file("res://main.tscn")

func _on_btn_3min_pressed():
	Global.game_time = 180
	get_tree().change_scene_to_file("res://main.tscn")

func _on_btn_practice_pressed():
	Global.game_time = 0
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
	
	for index in range(1, 6):
		if index <= Global.top_5_ranking.size():
			var r = Global.top_5_ranking[index - 1]
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
