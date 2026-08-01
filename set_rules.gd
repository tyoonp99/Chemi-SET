class_name SetRules
extends RefCounted

# 세 속성 각각이 모두 같거나 모두 다를 때만 세 카드는 SET이다.
const CARD_ATTRIBUTES := [&"shape", &"color", &"state"]

static func is_set(cards: Array) -> bool:
	if cards.size() != 3:
		return false

	for attribute in CARD_ATTRIBUTES:
		if not _has_set_value(cards[0], cards[1], cards[2], attribute):
			return false
	return true

static func _has_set_value(first: Variant, second: Variant, third: Variant, attribute: StringName) -> bool:
	if not (first is Dictionary and second is Dictionary and third is Dictionary):
		return false
	if not (first.has(attribute) and second.has(attribute) and third.has(attribute)):
		return false

	var first_value: Variant = first[attribute]
	var second_value: Variant = second[attribute]
	var third_value: Variant = third[attribute]
	var all_equal: bool = first_value == second_value and second_value == third_value
	var all_different: bool = first_value != second_value and first_value != third_value and second_value != third_value
	return all_equal or all_different
