extends Node

const UI_CLICK := preload("res://assets/audio/sfx/ui_click.ogg")
const SYNTHESIS_SUCCESS := preload("res://assets/audio/sfx/synthesis_success.ogg")
const FAILURE := preload("res://assets/audio/sfx/failure.ogg")
const COMPLETION_SUCCESS := preload("res://assets/audio/sfx/completion_success.ogg")

const CLICK_VOLUME_DB := -16.0
const SYNTHESIS_SUCCESS_VOLUME_DB := -10.0
const FAILURE_VOLUME_DB := -9.0
const COMPLETION_SUCCESS_VOLUME_DB := -7.0

var _players: Dictionary[StringName, AudioStreamPlayer] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_player(&"click", UI_CLICK)
	_create_player(&"synthesis_success", SYNTHESIS_SUCCESS)
	_create_player(&"failure", FAILURE)
	_create_player(&"completion_success", COMPLETION_SUCCESS)
	set_sfx_enabled(Global.is_sfx_enabled())

func set_sfx_enabled(enabled: bool) -> void:
	var bus_index := AudioServer.get_bus_index(&"SFX")
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, not enabled)

func is_sfx_enabled() -> bool:
	var bus_index := AudioServer.get_bus_index(&"SFX")
	return bus_index >= 0 and not AudioServer.is_bus_mute(bus_index)

func bind_clicks_in(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or button.has_meta("chemi_set_click_sound_bound"):
			continue
		button.set_meta("chemi_set_click_sound_bound", true)
		button.button_down.connect(play_ui_click)

func play_ui_click() -> void:
	_play(&"click", CLICK_VOLUME_DB)

func play_synthesis_success() -> void:
	_play(&"synthesis_success", SYNTHESIS_SUCCESS_VOLUME_DB)

func play_failure() -> void:
	_play(&"failure", FAILURE_VOLUME_DB)

func play_completion_success() -> void:
	_play(&"completion_success", COMPLETION_SUCCESS_VOLUME_DB)

func _create_player(effect_name: StringName, stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	_players[effect_name] = player

func _play(effect_name: StringName, volume_db: float) -> void:
	var player: AudioStreamPlayer = _players.get(effect_name)
	if player == null:
		return
	if player.playing:
		player.stop()
	player.volume_db = volume_db
	player.play()
