class_name PracticeHapHistory
extends HFlowContainer

const PATTERN_SCENE := preload("res://scenes/ui/practice_hap_pattern.tscn")

func set_haps(hap_keys: Array[String]) -> void:
	for child in get_children():
		child.queue_free()
	if hap_keys.is_empty():
		return
	for hap_key in hap_keys:
		var pattern := PATTERN_SCENE.instantiate() as PracticeHapPattern
		var parts: PackedStringArray = hap_key.split("-")
		add_child(pattern)
		pattern.set_pattern([int(parts[0]), int(parts[1]), int(parts[2])])
