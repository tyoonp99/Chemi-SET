class_name CardCatalog
extends RefCounted

# SET 카드의 표현 규칙을 한 곳에 둔다. 모드는 카드 데이터만 공유하고 UI는 각자 결정한다.
const SHAPE_NAMES := ["round", "tri", "tube"]
const COLOR_NAMES := ["red", "blue", "green"]
const STATE_NAMES := ["clear", "bubble", "sediment"]

static func create_full_deck() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	for shape in range(SHAPE_NAMES.size()):
		for color in range(COLOR_NAMES.size()):
			for state in range(STATE_NAMES.size()):
				deck.append({"shape": shape, "color": color, "state": state})
	return deck

static func texture_path_for(card: Dictionary) -> String:
	return texture_path_for_values(
		int(card.get("shape", -1)),
		int(card.get("color", -1)),
		int(card.get("state", -1))
	)

static func texture_path_for_values(shape: int, color: int, state: int) -> String:
	if not _is_valid_index(shape, SHAPE_NAMES.size()):
		return ""
	if not _is_valid_index(color, COLOR_NAMES.size()):
		return ""
	if not _is_valid_index(state, STATE_NAMES.size()):
		return ""
	return "res://assets/flasks/%s_%s_%s.png" % [
		SHAPE_NAMES[shape], COLOR_NAMES[color], STATE_NAMES[state]
	]

static func _is_valid_index(value: int, size: int) -> bool:
	return value >= 0 and value < size
