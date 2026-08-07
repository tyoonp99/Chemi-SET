extends Node

const SAVE_PATH := "user://ranking_data.json"
const BACKUP_SAVE_PATH := "user://ranking_data.backup.json"
const RANKING_LIMIT := 5
const MODE_SPEED: StringName = &"speed"
const MODE_GYULHAP: StringName = &"gyulhap"
const MODE_PRACTICE: StringName = &"practice"
const VALID_MODES := [MODE_SPEED, MODE_GYULHAP, MODE_PRACTICE]

var selected_mode: StringName = MODE_SPEED
var mode_config: Dictionary = {}
var rankings_by_mode: Dictionary = _create_empty_rankings()
var infinite_stats: Dictionary = _create_empty_infinite_stats()
var tutorial_completed := false
var sfx_enabled := true
var haptics_enabled := true

func _ready() -> void:
	load_data()

func configure_mode(mode: StringName, config: Dictionary = {}) -> void:
	selected_mode = mode if mode in VALID_MODES else MODE_SPEED
	mode_config = config.duplicate(true)

func get_mode_config() -> Dictionary:
	return mode_config.duplicate(true)

func load_data() -> void:
	rankings_by_mode = _create_empty_rankings()
	infinite_stats = _create_empty_infinite_stats()
	var data: Variant = _read_save_data(SAVE_PATH)
	if data == null:
		data = _read_save_data(BACKUP_SAVE_PATH)
	if data == null:
		save_data()
		return
	_load_rankings(data)
	_load_infinite_stats(data)
	_load_tutorial_state(data)
	_load_settings(data)
	save_data()

func save_data() -> void:
	var data := {
		"rankings_by_mode": rankings_by_mode,
		"infinite_stats": infinite_stats,
		"tutorial_completed": tutorial_completed,
		"settings": {
			"sfx_enabled": sfx_enabled,
			"haptics_enabled": haptics_enabled
		}
	}
	_write_save_data(SAVE_PATH, data)
	_write_save_data(BACKUP_SAVE_PATH, data)

func _read_save_data(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data if json.data is Dictionary or json.data is Array else null

func _write_save_data(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

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

func get_infinite_stats() -> Dictionary:
	return infinite_stats.duplicate(true)

func add_infinite_stats(hap_delta: int = 0, gyul_delta: int = 0) -> void:
	infinite_stats["hap"] = max(0, int(infinite_stats.get("hap", 0)) + hap_delta)
	infinite_stats["gyul"] = max(0, int(infinite_stats.get("gyul", 0)) + gyul_delta)
	save_data()

func has_completed_tutorial() -> bool:
	return tutorial_completed

func mark_tutorial_completed() -> void:
	tutorial_completed = true
	save_data()

func is_sfx_enabled() -> bool:
	return sfx_enabled

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	save_data()

func is_haptics_enabled() -> bool:
	return haptics_enabled

func set_haptics_enabled(enabled: bool) -> void:
	haptics_enabled = enabled
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

func _load_infinite_stats(data: Variant) -> void:
	if not data is Dictionary:
		return
	var raw_stats: Variant = data.get("infinite_stats", {})
	if not raw_stats is Dictionary:
		return
	infinite_stats = {
		"hap": max(0, int(raw_stats.get("hap", 0))),
		"gyul": max(0, int(raw_stats.get("gyul", 0)))
	}

func _load_tutorial_state(data: Variant) -> void:
	if data is Dictionary:
		tutorial_completed = bool(data.get("tutorial_completed", false))

func _load_settings(data: Variant) -> void:
	sfx_enabled = true
	haptics_enabled = true
	if not data is Dictionary:
		return
	var raw_settings: Variant = data.get("settings", {})
	if raw_settings is Dictionary:
		sfx_enabled = bool(raw_settings.get("sfx_enabled", true))
		haptics_enabled = bool(raw_settings.get("haptics_enabled", true))

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

func _create_empty_infinite_stats() -> Dictionary:
	return {"hap": 0, "gyul": 0}
