extends Control
## 房间布置浮层：全屏遮罩 + 网格编辑。
## 交互：长按家具 0.4s 拾起 → 移动 → 点击放下；保存把最终位置交给 GameMain 落盘。

signal layout_saved(objects: Array)
signal closed

var _is_open := false
var _tween: Tween
var _defaults: Array = []

@onready var grid: Control = $Panel/GridArea
@onready var note_label: Label = $Panel/HintLabel
@onready var reset_button: Button = $Panel/Buttons/ResetButton
@onready var save_button: Button = $Panel/Buttons/SaveButton
@onready var close_button: Button = $Panel/Buttons/CloseButton


func _ready() -> void:
	visible = false
	reset_button.pressed.connect(_on_reset_pressed)
	save_button.pressed.connect(_on_save_pressed)
	close_button.pressed.connect(close_overlay)
	grid.note_changed.connect(func(text: String) -> void: note_label.text = text)


func setup(objects: Array) -> void:
	_defaults = []
	for obj in objects:
		_defaults.append(obj.duplicate(true))
	grid.setup(objects)
	note_label.text = "长按家具 0.4 秒拾起 → 移动 → 点击放下；「恢复默认」可一键还原。"


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


func _on_reset_pressed() -> void:
	grid.setup(_defaults)
	note_label.text = "已恢复默认布局，点「保存并应用」生效。"


func _on_save_pressed() -> void:
	if grid.is_holding():
		note_label.text = "还有家具没放下，先放下再保存喵"
		return
	layout_saved.emit(grid.get_layout_objects())
	close_overlay()
