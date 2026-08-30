extends Control
## 角色对话气泡：显示简短反应文字，淡入停留后淡出。
## 由 GameMain 控制位置与内容；关闭时自动隐藏。

const DEFAULT_DURATION := 3.0
const MAX_TEXT_LEN := 36

var _tween: Tween

@onready var panel: PanelContainer = $Panel
@onready var label: RichTextLabel = $Panel/Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_bubble(text: String, duration: float = DEFAULT_DURATION) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		clean = "……"
	if clean.length() > MAX_TEXT_LEN:
		clean = clean.substr(0, MAX_TEXT_LEN) + "…"
	label.text = clean
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, 0.30)
	_tween.tween_callback(func() -> void: visible = false)
