class_name TutorialPopup
extends ColorRect

signal interactive_tutorial_requested
signal dismissed

@onready var _basic_tab: Button = %TutorialBasicTab
@onready var _speed_tab: Button = %TutorialSpeedTab
@onready var _gyulhap_tab: Button = %TutorialGyulHapTab
@onready var _infinite_tab: Button = %TutorialInfiniteTab
@onready var _basic_page: VBoxContainer = %TutorialBasicPage
@onready var _speed_page: VBoxContainer = %TutorialSpeedPage
@onready var _gyulhap_page: VBoxContainer = %TutorialGyulHapPage
@onready var _infinite_page: VBoxContainer = %TutorialInfinitePage
@onready var _close_button: Button = %TutorialCloseButton
@onready var _interactive_button: Button = %InteractiveTutorialButton
@onready var _example_one: Label = %ValidExplanation
@onready var _example_two: Label = %ValidExampleTwo
@onready var _example_three: Label = %ValidExampleThree
@onready var _invalid_example: Label = %InvalidExplanation
@onready var _valid_title: Label = %ValidTitle

func _ready() -> void:
	_valid_title.text = "✓ 합성이 되는 조합\n예시 1 · 모양은 같고, 색상·내용물은 모두 다름"
	_example_one.hide()
	_example_two.text = "예시 2 · 색상은 같고, 나머지는 모두 다름"
	_example_three.hide()
	_invalid_example.text = "내용물 상태가 맑음·침전·맑음으로\n2개만 같아 성립하지 않아요."
	_invalid_example.show()
	_basic_tab.pressed.connect(func() -> void: _show_page(0))
	_speed_tab.pressed.connect(func() -> void: _show_page(1))
	_gyulhap_tab.pressed.connect(func() -> void: _show_page(2))
	_infinite_tab.pressed.connect(func() -> void: _show_page(3))
	_close_button.pressed.connect(dismiss)
	_interactive_button.pressed.connect(func() -> void:
		hide()
		interactive_tutorial_requested.emit()
	)
	_show_page(0)

func open() -> void:
	_show_page(0)
	show()

func dismiss() -> void:
	hide()
	dismissed.emit()

func _show_page(page_index: int) -> void:
	var pages: Array[Control] = [_basic_page, _speed_page, _gyulhap_page, _infinite_page]
	var tabs: Array[Button] = [_basic_tab, _speed_tab, _gyulhap_tab, _infinite_tab]
	for index in pages.size():
		pages[index].visible = index == page_index
		tabs[index].button_pressed = index == page_index
