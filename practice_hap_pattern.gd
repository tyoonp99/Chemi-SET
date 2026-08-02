class_name PracticeHapPattern
extends PanelContainer

const EMPTY_STYLE := preload("res://practice_pattern_empty.tres")
const FILLED_STYLE := preload("res://practice_pattern_filled.tres")

@onready var _grid: GridContainer = %PatternGrid

func set_pattern(indices: Array[int]) -> void:
	for index in _grid.get_child_count():
		var cell := _grid.get_child(index) as Panel
		cell.add_theme_stylebox_override("panel", FILLED_STYLE if index in indices else EMPTY_STYLE)
