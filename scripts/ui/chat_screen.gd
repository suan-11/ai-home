extends Control
## 聊天应用：与梅尔对话。
## - 记忆：MemoryManager 构建上下文（人设 + 长期记忆 + 近期对话），每轮自动记录
## - 好感度：回复成功后由 AI 按人设判断本轮是否 +1（每日上限 GameManager.CHAT_DAILY_CAP）

signal back_requested

const CHAR_ID := "char_03"

var _char_id := CHAR_ID
var _messages: Array = []
var _waiting := false
var _judging := false

@onready var message_label: RichTextLabel = $ScrollContainer/MessageLabel
@onready var input_edit: LineEdit = $BottomBar/InputEdit
@onready var send_button: Button = $BottomBar/SendButton


func _ready() -> void:
	_char_id = GameManager.CURRENT_CHAR_ID
	var system_prompt := MemoryManager.get_persona_system(_char_id)
	_messages = MemoryManager.build_chat_context(_char_id, system_prompt)
	_show_history()

	AIConnector.chat_reply.connect(_on_chat_reply)
	AIConnector.error_occurred.connect(_on_chat_error)
	$BackButton.pressed.connect(_on_back_pressed)
	send_button.pressed.connect(_on_send_pressed)
	input_edit.text_submitted.connect(func(_text: String) -> void: _on_send_pressed())


func _draw() -> void:
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.20, 0.16, 0.20, 0.98))
	draw_rect(Rect2(Vector2(4, 4), Vector2(size.x - 8, 30)), Color(0.16, 0.13, 0.18))


func _show_history() -> void:
	var history := MemoryManager.get_short_term(_char_id)
	if history.is_empty():
		_append_message("梅尔", "数据呢喵。说正事喵。")
		return
	for entry in history:
		var who := "主人" if str(entry["role"]) == "user" else "梅尔"
		_append_message(who, str(entry["content"]))


func _on_send_pressed() -> void:
	if _waiting or _judging:
		return
	var text := input_edit.text.strip_edges()
	if text.is_empty():
		return
	input_edit.text = ""
	_append_message("主人", text)
	_messages.append({"role": "user", "content": text})
	MemoryManager.record_chat(_char_id, "user", text)
	_waiting = true
	send_button.disabled = true
	input_edit.editable = false
	AIConnector.send_chat(_messages)


func _on_chat_reply(text: String) -> void:
	_waiting = false
	_messages.append({"role": "assistant", "content": text})
	MemoryManager.record_chat(_char_id, "assistant", text)
	MemoryManager.maybe_summarize(_char_id)
	_append_message("梅尔", text)
	_start_affection_judgement()


func _start_affection_judgement() -> void:
	if _judging:
		return
	_judging = true
	send_button.disabled = true
	input_edit.editable = false
	var judge_messages: Array = []
	for msg in _messages:
		judge_messages.append(msg)
	judge_messages.append({
		"role": "user",
		"content": "【好感度判定】基于刚才这轮对话，判断梅尔是否对主人产生好感（可+1）：被夸奖、关心、投喂、分享、一起玩、认真倾听等会加分；无意义寒暄、命令、冒犯不会。只输出JSON，不要其他文字：{\"affection\": true或false, \"reason\": \"10字以内理由\"}",
	})
	AIConnector.request_json(
		judge_messages,
		_on_affection_judged,
		_on_affection_error
	)


func _on_affection_judged(data: Dictionary) -> void:
	_judging = false
	send_button.disabled = false
	input_edit.editable = true
	var eligible := bool(data.get("affection", false))
	var reason := str(data.get("reason", "对话内容"))
	if eligible and GameManager.add_chat_affection(_char_id, true, reason):
		var gain := GameManager.get_today_chat_gain(_char_id)
		_append_message(
			"系统",
			"（好感 +1：%s · 今日 %d/%d）" % [reason, gain, GameManager.CHAT_DAILY_CAP]
		)


func _on_affection_error(_message: String) -> void:
	_judging = false
	send_button.disabled = false
	input_edit.editable = true


func _on_chat_error(message: String) -> void:
	if not _waiting:
		return
	_waiting = false
	send_button.disabled = false
	input_edit.editable = true
	_append_message("系统", message)


func _append_message(who: String, text: String) -> void:
	var color := "#f2e0c0"
	if who == "主人":
		color = "#9fd0ff"
	elif who == "系统":
		color = "#ff9f9f"
	message_label.append_text("[color=%s]%s：[/color]%s\n" % [color, who, text])


func _on_back_pressed() -> void:
	back_requested.emit()
