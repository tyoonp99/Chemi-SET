extends Control

func _ready():
    # --- 🌟 수정됨: 아래쪽 함수 이름과 정확히 맞췄습니다 ---
    %StartButton.pressed.connect(_on_start_button_pressed)
    %QuitButton.pressed.connect(_on_quit_button_pressed)
    
    # --- 새로 추가한 튜토리얼 버튼 연결 코드 ---
    %TutorialButton.pressed.connect(_on_tutorial_pressed)
    %CloseButton.pressed.connect(_on_close_pressed)
    
    # --- 최초 1회 자동 팝업 로직 ---
    if Global.is_first_run == true:
        %TutorialPopup.show()
        Global.is_first_run = false
        Global.save_data() # 나중에 세이브 함수 만들면 주석 해제!
    else:
        %TutorialPopup.hide()

# --- 버튼을 눌렀을 때 실행될 함수들 ---
func _on_tutorial_pressed():
    %TutorialPopup.show() # 게임 방법 버튼 누르면 팝업 켜기

func _on_close_pressed():
    %TutorialPopup.hide() # 투명 버튼 누르면 팝업 끄기

func _on_start_button_pressed():
    # 💡 게임 시작: 메인 씬(main.tscn)으로 화면을 전환합니다!
    get_tree().change_scene_to_file("res://main.tscn")

func _on_quit_button_pressed():
    # 💡 게임 종료: 프로그램을 완전히 끕니다.
    get_tree().quit()
