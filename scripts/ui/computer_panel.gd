extends Control
## 电脑桌交互面板：
## - 覆盖在屏幕中央的半透明宫格界面
## - 四宫格：游戏 / 聊天 / 日记 / 空位
## - 打开/关闭带淡入淡出和缩放动画

signal closed
signal action_requested(action_name: String)

var _is_open := false
var _tween: Tween

@onready var panel: Panel = $Panel
@onready var info_label: Label = $Panel/InfoLabel


func _ready() -> void:
	visible = false
	$Panel/CloseButton.pressed.connect(close_panel)
	$Panel/Grid/GameButton.pressed.connect(_on_game_pressed)
	$Panel/Grid/ChatButton.pressed.connect(_on_chat_pressed)
	$Panel/Grid/DiaryButton.pressed.connect(_on_diary_pressed)


func open_panel() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true

	modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.85, 0.85)

	_tween = create_tween().set_parallel()
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	_tween.tween_property(panel, "scale", Vector2.ONE, 0.32)


func close_panel() -> void:
	if not _is_open:
		return
	_is_open = false

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_tween.tween_callback(_finish_close)


func _finish_close() -> void:
	visible = false
	closed.emit()


func _on_game_pressed() -> void:
	info_label.text = "游戏：AI 对战小游戏（待接入）"
	action_requested.emit("game")


func _on_chat_pressed() -> void:
	info_label.text = "聊天：AI 对话 API 接口已预留"
	action_requested.emit("chat")


func _on_diary_pressed() -> void:
	info_label.text = "日记：角色好感度 / 记忆（待完善）"
	action_requested.emit("diary")
