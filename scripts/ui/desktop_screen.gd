extends Control
## 电脑桌面屏幕：显示系统应用图标（游戏/聊天/日记）。

signal game_requested
signal chat_requested
signal diary_requested
@onready var info_label: Label = $InfoLabel


func _ready() -> void:
	$Grid/GameButton.pressed.connect(_on_game_pressed)
	$Grid/ChatButton.pressed.connect(_on_chat_pressed)
	$Grid/DiaryButton.pressed.connect(_on_diary_pressed)


func _on_game_pressed() -> void:
	info_label.text = "打开游戏中心…"
	game_requested.emit()


func _on_chat_pressed() -> void:
	info_label.text = "聊天：AI 对话 API 接口已预留"
	chat_requested.emit()


func _on_diary_pressed() -> void:
	info_label.text = "日记：角色好感度 / 记忆（待完善）"
	diary_requested.emit()
