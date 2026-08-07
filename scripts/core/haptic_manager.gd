extends Node

const SYNTHESIS_SUCCESS_DURATION_MS := 35
const SYNTHESIS_SUCCESS_AMPLITUDE := 0.35
const SYNTHESIS_FAILURE_DURATION_MS := 80
const SYNTHESIS_FAILURE_AMPLITUDE := 0.55
const COMPLETION_SUCCESS_DURATION_MS := 140
const COMPLETION_SUCCESS_AMPLITUDE := 0.8
const MINIMUM_INTERVAL_MS := 45

var _last_vibration_at_ms := -MINIMUM_INTERVAL_MS

func play_synthesis_success() -> void:
	_vibrate(SYNTHESIS_SUCCESS_DURATION_MS, SYNTHESIS_SUCCESS_AMPLITUDE)

func play_synthesis_failure() -> void:
	_vibrate(SYNTHESIS_FAILURE_DURATION_MS, SYNTHESIS_FAILURE_AMPLITUDE)

func play_completion_success() -> void:
	_vibrate(COMPLETION_SUCCESS_DURATION_MS, COMPLETION_SUCCESS_AMPLITUDE)

func _vibrate(duration_ms: int, amplitude: float) -> void:
	if not Global.is_haptics_enabled():
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_vibration_at_ms < MINIMUM_INTERVAL_MS:
		return
	_last_vibration_at_ms = now_ms
	Input.vibrate_handheld(duration_ms, amplitude)
