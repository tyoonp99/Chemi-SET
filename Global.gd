extends Node

const SAVE_PATH = "user://ranking_data.json"

# 게임 시작 시 타이틀 화면에서 전달받을 제한 시간 변수 (기본값 0)
var game_time: int = 0

# 🌟 추가된 변수: 최초 실행 여부
var is_first_run: bool = true

# 랭킹 데이터 창고
var top_5_ranking = [
	{"name": "---", "score": 000, "combo": 0},
	{"name": "---", "score": 000, "combo": 0},
	{"name": "---", "score": 000, "combo": 0},
	{"name": "---", "score": 000, "combo": 0},
	{"name": "---", "score": 000, "combo": 0}
]

func _ready():
	load_data() 

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var parsed_data = json.data
			
			# 💡 기존 세이브 파일(배열)과 새 세이브 파일(딕셔너리) 호환 처리
			if typeof(parsed_data) == TYPE_ARRAY:
				top_5_ranking = parsed_data
			elif typeof(parsed_data) == TYPE_DICTIONARY:
				if parsed_data.has("ranking"):
					top_5_ranking = parsed_data["ranking"]
				if parsed_data.has("is_first_run"):
					is_first_run = parsed_data["is_first_run"]
					
			print("✅ Global: 게임 데이터 불러오기 성공!")
	else:
		save_data()

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	# 🌟 랭킹과 최초 실행 여부를 하나의 딕셔너리(통)에 담아서 저장
	var save_dict = {
		"is_first_run": is_first_run,
		"ranking": top_5_ranking
	}
	file.store_string(JSON.stringify(save_dict))

func check_high_score(final_score):
	if top_5_ranking.size() < 5:
		return true
	return final_score > top_5_ranking[4]["score"]
