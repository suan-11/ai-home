class_name CommonStatusBar
extends Label
## 通用状态栏：底部提示/回执信息（居中、次要色）。
## 统一由代码创建或接入，避免各界面重复手写底部 Label 锚点。

func _init() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(0, UIConstants.STATUS_H)
	set_theme_color_override(
		"font_color",
		Color(0.564706, 0.505882, 0.427451)
	)


func set_status(message: String) -> void:
	text = message
