extends Control
## 聊天应用：与梅尔对话。
## - 记忆：MemoryManager 构建上下文（人设 + 长期记忆 + 近期对话），每轮自动记录
## - 好感度：回复成功后由 AI 按人设判断本轮是否 +1（每日上限 GameManager.CHAT_DAILY_CAP）

signal back_requested

const CHAR_ID := "char_03"

var _char_id := CHAR_ID
var _char_name := "梅尔"
var _messages: Array = []
var _waiting := false
var _judging := false

@onready var message_label: RichTextLabel = $ScrollContainer/MessageLabel
@onready var input_edit: LineEdit = $BottomBar/InputEdit
@onready var send_button: Button = $BottomBar/SendButton


func _ready() -> void:
	_char_id = GameManager.get_current_char_id()
	_char_name = CharacterCatalog.get_display_name(_char_id)
	$Title.text = "聊天 · %s" % _char_name
	input_edit.placeholder_text = "和%s说点什么…" % _char_name
	var system_prompt := MemoryManager.get_persona_system(_char_id)
	_messages = MemoryManager.build_chat_context(_char_id, system_prompt)
	_show_history()

	AIConnector.chat_reply.connect(_on_chat_reply)
	AIConnector.error_occurred.connect(_on_chat_error)
	$BackButton.pressed.connect(_on_back_pressed)
	send_button.pressed.connect(_on_send_pressed)
	input_edit.text_submitted.connect(func(_text: String) -> void: _on_send_pressed())


func _draw() -> void:
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.16, 0.12, 0.10, 0.98))
	draw_rect(Rect2(Vector2(4, 4), Vector2(size.x - 8, 30)), Color(0.42, 0.31, 0.23))


func _show_history() -> void:
	var history := MemoryManager.get_short_term(_char_id)
	if history.is_empty():
		_append_message(_char_name, "数据呢。说正事。")
		return
	for entry in history:
		var who := "主人" if str(entry["role"]) == "user" else _char_name
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
	_append_message(_char_name, text)
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
		"content": "【好感度判定】基于刚才这轮对话，判断%s是否对主人产生好感（可+1）：被夸奖、关心、投喂、分享、一起玩、认真倾听等会加分；无意义寒暄、命令、冒犯不会；同时给出这轮对话对%s心情的影响 mood_delta（-2 到 +3 的整数）。" % [_char_name, _char_name]
			+ "请只输出一个 JSON 对象（不要输出任何其他文字，不要用 Markdown 代码块），且必须符合 JSON 语法：键和字符串用双引号，布尔值用 true/false（不加引号），例如："
			+ "{\"affection\":true,\"reason\":\"被夸奖了\",\"mood_delta\":2}。affection 只能是 true 或 false，reason 是 10 字以内理由。",
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
	var eligible := _parse_affection(data.get("affection", false))
	var reason := str(data.get("reason", "")).strip_edges()
	if reason.is_empty():
		reason = "对话内容"
	if reason.length() > 20:
		reason = reason.substr(0, 20)
	StatusManager.apply_delta(0, _parse_mood_delta(data), 0)
	if eligible and GameManager.add_chat_affection(_char_id, true, reason):
		var gain := GameManager.get_today_chat_gain(_char_id)
		_append_message(
			"系统",
			"（好感 +1：%s · 今日 %d/%d）" % [reason, gain, GameManager.CHAT_DAILY_CAP]
		)


func _parse_affection(value) -> bool:
	## 兼容模型返回的多种形式：bool / 数值 / 字符串。
	if value is bool:
		return value
	if value is int or value is float:
		return int(value) != 0
	if value is String:
		var s := (value as String).strip_edges().to_lower()
		return s in ["true", "yes", "是", "y", "1", "对", "加分"]
	return false


func _parse_mood_delta(data: Dictionary) -> int:
	## mood_delta 缺省按 +1；范围钳制到 -2~+3。
	var value = data.get("mood_delta", 1)
	var delta := 1
	if value is int or value is float:
		delta = int(value)
	elif value is String:
		delta = int((value as String).strip_edges()) if (value as String).is_valid_int() else 1
	return clampi(delta, -2, 3)


func _on_affection_error(_message: String) -> void:
	_judging = false
	send_button.disabled = false
	input_edit.editable = true
	_append_message("系统", "（好感判定未完成，本轮跳过）")


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
