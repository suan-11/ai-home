extends Control
## 日记应用：按日期自动整理当天记忆（聊天/互动/好感度变化）。
## 有 API 时由 AI 按人设撰写；无 API 或失败时降级为规则拼接。

signal back_requested

const CHAR_ID := "char_03"

var _char_id := CHAR_ID
var _date := ""
var _busy := false

@onready var info_label: Label = $InfoLabel
@onready var date_label: Label = $DateBar/DateLabel
@onready var diary_label: RichTextLabel = $ScrollContainer/DiaryLabel
@onready var organize_button: Button = $BottomBar/OrganizeButton
@onready var status_label: Label = $BottomBar/StatusLabel


func _ready() -> void:
	_char_id = GameManager.get_current_char_id()
	var char_name := CharacterCatalog.get_display_name(_char_id)
	$Title.text = "日记 · %s" % char_name
	_date = MemoryManager.today()
	$BackButton.pressed.connect(_on_back_pressed)
	$DateBar/PrevButton.pressed.connect(func() -> void: _step_date(-1))
	$DateBar/NextButton.pressed.connect(func() -> void: _step_date(1))
	$DateBar/TodayButton.pressed.connect(_on_today_pressed)
	organize_button.pressed.connect(_on_organize_pressed)
	MemoryManager.diary_updated.connect(_on_diary_updated)
	_refresh()
	if MemoryManager.get_diary(_char_id, _date).is_empty():
		_organize()


func _draw() -> void:
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.16, 0.12, 0.10, 0.98))
	draw_rect(Rect2(Vector2(4, 4), Vector2(size.x - 8, 30)), Color(0.42, 0.31, 0.23))


func _refresh() -> void:
	var affection := GameManager.get_affection(_char_id)
	var chat_gain := GameManager.get_today_chat_gain(_char_id)
	info_label.text = "好感度 %d/100　今日聊天好感 %d/%d" % [
		affection, chat_gain, GameManager.CHAT_DAILY_CAP,
	]
	date_label.text = _date
	var diary := MemoryManager.get_diary(_char_id, _date)
	if diary.is_empty():
		diary_label.text = "这一天还没有整理日记。\n点下方「整理日记」生成。"
	else:
		diary_label.text = diary
	if not _busy:
		status_label.text = ""


func _on_diary_updated(char_id: String, date: String) -> void:
	if char_id != _char_id or date != _date:
		return
	_busy = false
	_refresh()


func _on_organize_pressed() -> void:
	_organize()


func _organize() -> void:
	if _busy:
		return
	_busy = true
	status_label.text = "整理中…"
	MemoryManager.generate_diary(_char_id, _date, true)


func _on_today_pressed() -> void:
	if _busy:
		return
	_date = MemoryManager.today()
	_refresh()
	if MemoryManager.get_diary(_char_id, _date).is_empty():
		_organize()


func _step_date(days: int) -> void:
	if _busy:
		return
	var unix := Time.get_unix_time_from_datetime_string(_date + "T00:00:00")
	unix += days * 86400
	_date = Time.get_datetime_string_from_unix_time(unix, true).substr(0, 10)
	_refresh()


func _on_back_pressed() -> void:
	back_requested.emit()
