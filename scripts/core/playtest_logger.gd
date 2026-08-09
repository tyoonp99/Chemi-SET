extends Node

const LOG_PATH := "user://playtest_log.jsonl"
const LOG_SCHEMA_VERSION := 1

var _session_id := ""
var _logging_enabled := false

func _ready() -> void:
	_logging_enabled = OS.is_debug_build()
	if not _logging_enabled:
		return
	_session_id = "%d-%08x" % [Time.get_unix_time_from_system(), randi()]
	log_event(&"system", &"session_started", {
		"engine": Engine.get_version_info().get("string", "unknown")
	})

func log_event(mode: StringName, event_name: StringName, data: Dictionary = {}) -> void:
	if not _logging_enabled:
		return
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE_READ)
	if file == null:
		push_warning("Playtest log could not be opened.")
		return
	file.seek_end()
	file.store_line(JSON.stringify({
		"schema": LOG_SCHEMA_VERSION,
		"session_id": _session_id,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"timestamp_ms": Time.get_ticks_msec(),
		"mode": String(mode),
		"event": String(event_name),
		"data": data
	}))

func get_log_path() -> String:
	return LOG_PATH

func clear_logs() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))
