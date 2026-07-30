extends Node

# ---------------------------------------------------------
# 팝업창 UI 테마 세팅 함수
# ---------------------------------------------------------
func _setup_popup_ui():
	# 1. 팝업창 반투명 배경 (다크 네이비, Alpha 85%)
	var overlay_color = Color("#050b14")
	overlay_color.a = 0.85 
	
	# UILayer 본인이므로 $UILayer/ 를 뺐습니다.
	$PausePanel.color = overlay_color
	$GameOverPanel.color = overlay_color
	$"%HighScorePanel".color = overlay_color # Unique Name 사용

	# 2. 타이포그래피 (제목 글씨 흰색으로 강조해서 가독성 확보)
	$PausePanel/VBoxContainer/Label.add_theme_color_override("font_color", Color.WHITE)
	$GameOverPanel/VBoxContainer/GameOverLabel.add_theme_color_override("font_color", Color.WHITE)
	# HighScorePanel은 씬 트리에 %가 붙어있으므로 고유 이름으로 찾습니다.
	$"%HighScorePanel/VBoxContainer/Label".add_theme_color_override("font_color", Color.WHITE)

	# 3. 버튼들 스타일 적용 (메인 버튼 = true, 서브 버튼 = false)
	# --- PausePanel ---
	_apply_btn_style($PausePanel/VBoxContainer/ContinueButton, true)
	_apply_btn_style($PausePanel/VBoxContainer/SoundButton, false)
	_apply_btn_style($PausePanel/VBoxContainer/RestartButton2, false)
	_apply_btn_style($PausePanel/VBoxContainer/TitleButton, false)

	# --- GameOverPanel --- (게임오버 패널의 실제 버튼 경로에 맞춰 수정 필요)
	# 예시: _apply_btn_style($GameOverPanel/VBoxContainer/HBoxContainer/RestartButton, true) 

	# --- HighScorePanel --- (제출 버튼 고유 이름 사용)
	# 예시: _apply_btn_style($"%SubmitButton", true) 


# ---------------------------------------------------------
# 버튼 상태(Normal/Hover/Pressed) 및 디자인 자동 생성 함수
# ---------------------------------------------------------
func _apply_btn_style(btn: Button, is_main: bool):
	var base_style = StyleBoxFlat.new()
	base_style.corner_radius_top_left = 12
	base_style.corner_radius_top_right = 12
	base_style.corner_radius_bottom_right = 12
	base_style.corner_radius_bottom_left = 12
	base_style.content_margin_left = 30
	base_style.content_margin_right = 30
	base_style.content_margin_top = 15
	base_style.content_margin_bottom = 15

	var normal = base_style.duplicate()
	var hover = base_style.duplicate()
	var pressed = base_style.duplicate()

	if is_main: 
		normal.bg_color = Color("#4361EE")
		hover.bg_color = Color("#5C7CFA")
		pressed.bg_color = Color("#364FC7")
	else: 
		normal.bg_color = Color("#27354D")
		hover.bg_color = Color("#344665")
		pressed.bg_color = Color("#151D2C")

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color.WHITE)
