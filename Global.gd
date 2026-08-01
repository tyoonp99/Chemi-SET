extends Node

const SAVE_PATH := "user://ranking_data.json"
const RANKING_LIMIT := 5
const MODE_SPEED: StringName = &"speed"
const MODE_GYULHAP: StringName = &"gyulhap"
const MODE_PRACTICE: StringName = &"practice"
const VALID_MODES := [MODE_SPEED, MODE_GYULHAP, MODE_PRACTICE]

var selected_mode: StringName = MODE_SPEED
var mode_config: Dictionary = {}
var rankings_by_mode: Dictionary = _create_empty_rankings()

func _ready() -> void:
	load_data()

func configure_mode(mode: StringName, config: Dictionary = {}) -> void:
	selected_mode = mode if mode in VALID_MODES else MODE_SPEED
	mode_config = config.duplicate(true)

func get_mode_config() -> Dictionary:
	return mode_config.duplicate(true)

func load_data() -> void:
	rankings_by_mode = _create_empty_rankings()
	if not FileAccess.file_exists(SAVE_PATH):
		save_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		save_data()
		return

	_load_rankings(json.data)
	save_data()

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"rankings_by_mode": rankings_by_mode}))

func get_rankings_for_mode(mode: StringName = selected_mode) -> Array:
	var rankings: Array = rankings_by_mode.get(mode, [])
	return rankings.duplicate(true)

func check_high_score(final_score: int, mode: StringName = selected_mode) -> bool:
	var rankings := get_rankings_for_mode(mode)
	return rankings.size() < RANKING_LIMIT or final_score > int(rankings.back()["score"])

func add_high_score(mode: StringName, player_name: String, score: int, combo: int) -> void:
	var target_mode: StringName = mode if mode in VALID_MODES else MODE_SPEED
	var rankings: Array = rankings_by_mode.get(target_mode, [])
	rankings.append({
		"name": _sanitize_name(player_name),
		"score": max(0, score),
		"combo": max(0, combo)
	})
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	if rankings.size() > RANKING_LIMIT:
		rankings.resize(RANKING_LIMIT)
	rankings_by_mode[target_mode] = rankings
	save_data()

func _load_rankings(data: Variant) -> void:
	if data is Array:
		rankings_by_mode[MODE_SPEED] = _sanitize_rankings(data)
		return
	if not data is Dictionary:
		return

	var source: Variant = data.get("rankings_by_mode", data.get("ranking", []))
	if source is Array:
		rankings_by_mode[MODE_SPEED] = _sanitize_rankings(source)
		return
	if source is Dictionary:
		for mode in VALID_MODES:
			rankings_by_mode[mode] = _sanitize_rankings(source.get(mode, []))

func _sanitize_rankings(raw_rankings: Variant) -> Array:
	var rankings: Array = []
	if not raw_rankings is Array:
		return rankings
	for record in raw_rankings:
		if not record is Dictionary:
			continue
		rankings.append({
			"name": _sanitize_name(str(record.get("name", "P1"))),
			"score": max(0, int(record.get("score", 0))),
			"combo": max(0, int(record.get("combo", 0)))
		})
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	if rankings.size() > RANKING_LIMIT:
		rankings.resize(RANKING_LIMIT)
	return rankings

func _sanitize_name(raw_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9]")
	var sanitized := regex.sub(raw_name, "", true).to_upper().left(3)
	return sanitized if not sanitized.is_empty() else "P1"

func _create_empty_rankings() -> Dictionary:
	return {
		MODE_SPEED: [],
		MODE_GYULHAP: [],
		MODE_PRACTICE: []
	}
