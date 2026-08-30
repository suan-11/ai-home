extends Control
## 手机消息通知：屏幕顶部小横幅（手机图标 + 文案），淡入、停留、淡出。
## 由 GameMain 设定位置并调用 show_toast()。

const DEFAULT_DURATION := 1.6

var _tween: Tween

@onready var label: Label = $Panel/HBox/Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size / 2.0


func show_toast(text: String = "梅尔 收到了新消息", duration: float = DEFAULT_DURATION) -> void:
	label.text = text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func() -> void: visible = false)
