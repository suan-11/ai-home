extends Control
## 主界面设置浮层：全屏遮罩 + 复用设置应用。

signal closed

const SETTINGS_SCENE := preload("res://scenes/ui/settings_screen.tscn")

var _settings_screen: Control = null
var _tween: Tween
var _is_open := false


func _ready() -> void:
	visible = false
	_settings_screen = SETTINGS_SCENE.instantiate()
	add_child(_settings_screen)
	_settings_screen.back_requested.connect(close_overlay)


func open_overlay() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)


func close_overlay() -> void:
	if not _is_open:
		return
	_is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.16)
	_tween.tween_callback(_finish_close)


func _finish_close() -> void:
	visible = false
	closed.emit()
