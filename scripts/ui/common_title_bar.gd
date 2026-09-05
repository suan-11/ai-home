class_name CommonTitleBar
extends HBoxContainer
## 通用标题栏：左侧标题 + 右侧返回/关闭按钮。
## 由代码构建，无需单独 tscn；批次 1 起替换各界面自制的 Title+CloseButton。

signal back_requested

@export var title_text := "标题":
	set(value):
		title_text = value
		if _title_label != null:
			_title_label.text = value

@export var button_text := "返回":
	set(value):
		button_text = value
		if _button != null:
			_button.text = value

var _title_label: Label
var _button: Button


func _ready() -> void:
	add_theme_constant_override("separation", UIConstants.GAP)

	_title_label = Label.new()
	_title_label.text = title_text
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title_label)

	_button = Button.new()
	_button.text = button_text
	_button.custom_minimum_size = Vector2(56, 0)
	_button.pressed.connect(_on_button_pressed)
	add_child(_button)


func _on_button_pressed() -> void:
	back_requested.emit()
