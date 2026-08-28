extends Control
## 游戏选择界面。
## 后续新增小游戏时，在面板中增加对应按钮并在这里打开。

signal back_requested

const GOMOKU_SCENE := preload("res://scenes/ui/gomoku_game.tscn")

var _current_game: Control = null

@onready var status_label: Label = $Panel/StatusLabel


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	$Panel/GomokuButton.pressed.connect(_on_gomoku_pressed)
	$Panel/FutureButton.pressed.connect(_on_future_pressed)
	$Panel/BackButton.pressed.connect(_on_back_pressed)


func _on_gomoku_pressed() -> void:
	if _current_game != null:
		return
	status_label.text = "正在进入五子棋…"
	_current_game = GOMOKU_SCENE.instantiate()
	add_child(_current_game)
	_current_game.back_requested.connect(_close_gomoku)


func _close_gomoku() -> void:
	if _current_game == null:
		return
	_current_game.queue_free()
	_current_game = null
	status_label.text = "请选择游戏"


func _on_future_pressed() -> void:
	status_label.text = "后续游戏待添加"


func _on_back_pressed() -> void:
	back_requested.emit()
