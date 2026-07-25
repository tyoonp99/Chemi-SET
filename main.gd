extends Control

# ==============================================================================
# 🎮 게임 변수 세팅
# ==============================================================================
const FLASK_CARD_SCENE = preload("res://flask_card.tscn")

var selected_cards = []  # 유저가 클릭한 카드의 인덱스 번호 저장
var full_deck = []       # 게임에 쓰일 전체 카드 27장 덱
var board_cards = []     # 현재 보드판(화면)에 깔려있는 9장의 카드

# 카드 속성 정의 (모양, 색상, 상태)
var shape_names = ["round", "tri", "tube"]
var color_names = ["red", "blue", "green"]
var state_names = ["clear", "bubble", "sediment"]

var score = 0            # 현재 점수
var combo = 0            # 현재 실시간 콤보
var max_combo = 0        # 영구 누적 기록되는 최대 콤보
var is_game_over = false # 게임 종료 상태 확인 스위치

# ==============================================================================
# 🎬 게임 시작 (초기화)
# ==============================================================================
func _ready():
	if Global.game_time > 0:
		if has_node("Timer"):
			$Timer.wait_time = Global.game_time
			$Timer.start()
	else:
		if has_node("Timer"):
			$Timer.stop()

	if has_node("%HighScorePanel"):
		$%HighScorePanel.hide()
		
	# 💡 일시정지 버튼 연결 (추가됨)
	if has_node("%PauseButton"):
		%PauseButton.pressed.connect(_on_pause_button_pressed)
	
	for s in range(3):
		for c in range(3):
			for t in range(3):
				full_deck.append({"shape": s, "color": c, "state": t})
	full_deck.shuffle() 

	for i in range(9):
		var card_data = full_deck.pop_back()
		board_cards.append(card_data)
		
		var btn_container = %GridContainer.get_child(i)
		var flask_card = FLASK_CARD_SCENE.instantiate()
		
		flask_card.flask_shape = shape_names[card_data["shape"]]
		flask_card.flask_color = color_names[card_data["color"]]
		flask_card.flask_state = state_names[card_data["state"]]
		
		btn_container.add_child(flask_card)
		
		var sprite = flask_card.get_node("FlaskSprite")
		if sprite and sprite.texture:
			var texture_size = sprite.texture.get_size()
			flask_card.scale = btn_container.size / texture_size
		
		flask_card.position = btn_container.size / 2.0 

	var index = 1
	for btn in %GridContainer.get_children():
		btn.pressed.connect(_on_any_button_pressed.bind(index))
		index += 1

	if has_node("%SubmitButton"):
		$%SubmitButton.pressed.connect(_on_submit_button_pressed)
		
	# 초기 화면 점수 0점 세팅
	if has_node("%ScoreValueLabel"):
		%ScoreValueLabel.text = str(score)

# ==============================================================================
# ⏱️ 프레임 업데이트 (타이머)
# ==============================================================================
func _process(_delta):
	if not is_game_over:
		if Global.game_time > 0:
			var time_left = int($Timer.time_left)
			
			# 💡 초(Seconds)를 분:초(M:SS) 형식으로 변환 ("58" -> "0:58")
			var minutes = time_left / 60
			var seconds = time_left % 60
			var time_string = str(minutes) + ":" + str(seconds).pad_zeros(2)
			
			if has_node("%TimeValueLabel"):
				%TimeValueLabel.text = time_string
		else:
			if has_node("%TimeValueLabel"):
				%TimeValueLabel.text = "무제한"

# ==============================================================================
# 👆 클릭 이벤트 처리 (🎨 시각적 피드백 추가)
# ==============================================================================
func _on_any_button_pressed(btn_num):
	if is_game_over: return 
	
	var btn_container = %GridContainer.get_child(btn_num - 1)
	var flask_card = btn_container.get_child(0)
	
	if btn_num in selected_cards:
		selected_cards.erase(btn_num)
		flask_card.modulate = Color(1.0, 1.0, 1.0) # 선택 취소: 원래 색상
	else:
		selected_cards.append(btn_num)
		flask_card.modulate = Color(0.5, 0.5, 0.5, 0.8) # 선택됨: 약간 어둡고 투명하게
	
	if selected_cards.size() == 3:
		_check_answer()
		_reset_selection_visuals() # 판별 후 시각 효과 초기화
		selected_cards.clear()

func _reset_selection_visuals():
	for btn_num in selected_cards:
		var btn_container = %GridContainer.get_child(btn_num - 1)
		if btn_container.get_child_count() > 0:
			var flask_card = btn_container.get_child(0)
			flask_card.modulate = Color(1.0, 1.0, 1.0)

# ==============================================================================
# 🧠 정답 판별 (핵심 로직)
# ==============================================================================
func _check_answer():
	var c1 = board_cards[selected_cards[0] - 1]
	var c2 = board_cards[selected_cards[1] - 1]
	var c3 = board_cards[selected_cards[2] - 1]
	
	var shape_match = (c1["shape"] + c2["shape"] + c3["shape"]) % 3 == 0
	var color_match = (c1["color"] + c2["color"] + c3["color"]) % 3 == 0
	var state_match = (c1["state"] + c2["state"] + c3["state"]) % 3 == 0
	
	if shape_match and color_match and state_match:
		combo += 1
		if combo > max_combo:
			max_combo = combo
		
		var bonus = 0
		
		if combo >= 10:
			bonus = 100
		elif combo >= 7:
			bonus = 60
		elif combo >= 4:
			bonus = 30
			
		score += (100 + bonus)
		
		# 💡 점수만 깔끔하게 표시
		if has_node("%ScoreValueLabel"):
			%ScoreValueLabel.text = str(score)
		
		_refill_cards(selected_cards) 
	else:
		combo = 0
		if has_node("%ScoreValueLabel"):
			%ScoreValueLabel.text = str(score)

# ==============================================================================
# 🔄 카드 리필 (교체)
# ==============================================================================
func _refill_cards(matched_btn_nums):
	for btn_num in matched_btn_nums:
		var idx = btn_num - 1 
		
		full_deck.append(board_cards[idx])
		full_deck.shuffle()
		
		var new_card = full_deck.pop_back()
		board_cards[idx] = new_card
		
		var btn_container = %GridContainer.get_child(idx)
		var flask_card = btn_container.get_child(0) 
		
		flask_card.flask_shape = shape_names[new_card["shape"]]
		flask_card.flask_color = color_names[new_card["color"]]
		flask_card.flask_state = state_names[new_card["state"]]
		flask_card.update_flask_image(flask_card.flask_shape, flask_card.flask_color, flask_card.flask_state)

# ==============================================================================
# 🛑 게임 오버 & 재시작
# ==============================================================================
func _on_timer_timeout():
	is_game_over = true 
	
	if Global.check_high_score(score):
		if has_node("%HighScorePanel"):
			$%HighScorePanel.show()
			if has_node("%NameInput"):
				$%NameInput.grab_focus()
	else:
		_show_final_leaderboard()

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

# ==============================================================================
# 🏆 랭킹 등록 시스템
# ==============================================================================
func _on_submit_button_pressed():
	if not has_node("%NameInput"): return
	
	var raw_text = $%NameInput.text
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9]") 
	var filtered_text = regex.sub(raw_text, "", true)
	
	var player_name = filtered_text.strip_edges().to_upper().left(3)
	if player_name == "":
		player_name = "P1" 
		
	var new_record = {
		"name": player_name,
		"score": score,
		"combo": max_combo
	}
	
	Global.top_5_ranking.append(new_record)
	Global.top_5_ranking.sort_custom(func(a, b): return a["score"] > b["score"])
	
	if Global.top_5_ranking.size() > 5:
		Global.top_5_ranking.resize(5)
		
	Global.save_data()
	
	if has_node("%HighScorePanel"):
		$%HighScorePanel.hide()
	_show_final_leaderboard()

func _show_final_leaderboard():
	if not has_node("UILayer/GameOverPanel"): return
	
	var board_text = "🏆 HIGH SCORES 🏆\n\n"
	
	for index in range(1, 6):
		if index <= Global.top_5_ranking.size():
			var r = Global.top_5_ranking[index - 1]
			board_text += str(index) + "위  " + r["name"] + "   " + str(int(r["score"])) + "점\n"
		else:
			board_text += str(index) + "위  ---   0점\n"
		
	board_text += "\n내 점수: " + str(int(score)) + "점\n"
	
	if has_node("UILayer/GameOverPanel/VBoxContainer/GameOverLabel"):
		$UILayer/GameOverPanel/VBoxContainer/GameOverLabel.text = board_text
	else:
		$UILayer/GameOverPanel/GameOverLabel.text = board_text
	
	$UILayer/GameOverPanel.show()

# ==============================================================================
# ⏸️ 일시정지 / 설정 (팝업 기능 준비)
# ==============================================================================
func _on_pause_button_pressed():
	print("일시정지 버튼 눌림!")
