extends Area2D

# 씬에 있는 FlaskSprite 노드를 가져옴
@onready var sprite = $FlaskSprite

# 나중에 게임 로직에서 바꿔줄 3가지 속성
var flask_shape = "tri"      # round, tri, tube
var flask_color = "blue"     # red, blue, green
var flask_state = "sediment" # clear, bubble, sediment

func _ready():
	# 게임이 딱 켜졌을 때 이미지 업데이트 함수 실행!
	update_flask_image(flask_shape, flask_color, flask_state)

func update_flask_image(shape: String, color: String, state: String):
	# 우리가 피그마에서 지어준 이름 규칙 그대로 파일 경로를 조립!
	var file_path = "res://assets/flasks/%s_%s_%s.png" % [shape, color, state]
	
	# 조립된 경로의 이미지를 불러와서 텍스처로 입히기
	sprite.texture = load(file_path)


func _on_input_event(viewport, event, shape_idx):
	# 마우스 왼쪽 버튼이나 터치가 '눌렸을 때'만 작동!
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print(flask_color + "색 " + flask_shape + " 카드 클릭됨!")
