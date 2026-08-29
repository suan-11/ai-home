extends Control
## 游戏选择屏幕。
## 后续新增小游戏时，在场景中增加按钮并发出对应信号即可。

signal back_requested
signal gomoku_requested

@onready var status_label: Label = $WindowPanel/StatusLabel


func _ready() -> void:
	$WindowPanel/GomokuButton.pressed.connect(_on_gomoku_pressed)
	$WindowPanel/FutureButton.pressed.connect(_on_future_pressed)
	$WindowPanel/BackButton.pressed.connect(_on_back_pressed)


func _on_gomoku_pressed() -> void:
	status_label.text = "正在进入五子棋…"
	gomoku_requested.emit()


func _on_future_pressed() -> void:
	status_label.text = "后续游戏待添加"


func _on_back_pressed() -> void:
	back_requested.emit()
