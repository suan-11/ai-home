extends Control
## P0 手机消息：半透明竖屏聊天窗（单页，随时可聊）。
## - 复用 MemoryManager（记忆/日记）与 GameManager（好感度），与电脑聊天统一对待
## - AI 以结构化 JSON 返回：reply / emotion / action / affection / reason
## - 通过信号通知 GameMain：提示音、气泡、动作动画、家具指令

signal closed
signal notification_triggered
signal reaction(text: String, emotion: String)
signal action_requested(action_name: String)

const CHAR_ID := "char_03"
const RECEIVE_DELAY := 1.0   # 发送后，角色“看到消息”的延迟
const REPLY_DELAY := 0.8     # 通知后，AI 开始回复的延迟
const HINT_DURATION := 1.1   # 每行系统提示停留时长

var _char_id := CHAR_ID
var _messages: Array = []
var _waiting := false
var _is_open := false
var _hint_queue: Array = []
var _hint_showing := false
var _hint_base_pos: Vector2 = Vector2.ZERO

@onready var message_label: RichTextLabel = $Panel/ScrollContainer/MessageLabel
@onready var input_edit: LineEdit = $Panel/BottomBar/InputEdit
@onready var send_button: Button = $Panel/BottomBar/SendButton
@onready var close_button: Button = $Panel/CloseButton
@onready var hint_label: Label = $Panel/HintLabel


func _ready() -> void:
	_char_id = GameManager.CURRENT_CHAR_ID
	_hint_base_pos = hint_label.position
	var system_prompt := MemoryManager.get_persona_system(_char_id)
	_messages = MemoryManager.build_chat_context(_char_id, system_prompt)
	_show_history()
	close_button.pressed.connect(close_overlay)
	send_button.pressed.connect(_on_send_pressed)
	input_edit.text_submitted.connect(func(_text: String) -> void: _on_send_pressed())


func open_overlay() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)


func close_overlay() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()


func _show_history() -> void:
	var history := MemoryManager.get_short_term(_char_id)
	if history.is_empty():
		_append_message("梅尔", "数据呢喵。发消息说正事喵。")
		return
	for entry in history:
		var who := "主人" if str(entry["role"]) == "user" else "梅尔"
		_append_message(who, str(entry["content"]))


func _on_send_pressed() -> void:
	if _waiting:
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
	_enqueue_hint("已发送，等待查看…")

	# 1) 延迟：角色“收到消息”
	await get_tree().create_timer(RECEIVE_DELAY).timeout
	notification_triggered.emit()
	_enqueue_hint("梅尔收到了消息！")

	# 2) 小停顿后开始回复（触发 AI 结构化返回）
	await get_tree().create_timer(REPLY_DELAY).timeout
	if not _waiting:
		return
	_enqueue_hint("正在输入…")
	_request_ai()


func _request_ai() -> void:
	var request_messages: Array = _messages.duplicate(true)
	request_messages.append({
		"role": "user",
		"content": "这是一条通过手机发来的消息。请只输出一个 JSON 对象（不要输出任何其他文字，不要用 Markdown 代码块），"
			+ "且必须符合 JSON 语法：键和字符串用双引号，布尔值用 true/false（不加引号），最后不要逗号。格式："
			+ "{\"reply\":\"回复给主人的内容\",\"emotion\":\"happy或normal或surprised或sad\","
			+ "\"action\":\"wave或hop或sad或none或sleep或read或sit或watch或rest或light或water或computer\","
			+ "\"affection\":true或false,\"reason\":\"10字以内好评感理由\"}。"
			+ "示例：{\"reply\":\"好呀，来玩！\",\"emotion\":\"happy\",\"action\":\"wave\",\"affection\":true,\"reason\":\"愿意陪主人玩\"}。"
			+ "action 表示此刻想做的动作或想去的家具（sleep=床/read=书架/sit=椅子/watch=电视柜/rest=沙发/light=落地灯/water=盆栽/computer=电脑桌）。",
	})
	AIConnector.request_json(request_messages, _on_ai_reply, _on_ai_error)


func _on_ai_reply(data: Dictionary) -> void:
	_waiting = false
	_finish_ui()
	var reply := str(data.get("reply", "……"))
	var emotion := str(data.get("emotion", "normal"))
	var action := str(data.get("action", "none"))
	_messages.append({"role": "assistant", "content": reply})
	MemoryManager.record_chat(_char_id, "assistant", reply)
	MemoryManager.maybe_summarize(_char_id)
	_append_message("梅尔", reply)
	reaction.emit(reply, emotion)
	action_requested.emit(action)

	var eligible := bool(data.get("affection", false))
	var reason := str(data.get("reason", "手机消息"))
	if eligible and GameManager.add_chat_affection(_char_id, eligible, reason):
		var gain := GameManager.get_today_chat_gain(_char_id)
		_enqueue_hint("好感 +1 · 今日 %d/%d" % [gain, GameManager.CHAT_DAILY_CAP])


func _on_ai_error(message: String) -> void:
	if not _waiting:
		return
	_waiting = false
	_finish_ui()
	_append_message("系统", message)


func _finish_ui() -> void:
	send_button.disabled = false
	input_edit.editable = true


## ---------------- 右上角系统提示（一行一行队列） ----------------

func _enqueue_hint(text: String) -> void:
	_hint_queue.append(text)
	_process_hint_queue()


func _process_hint_queue() -> void:
	if _hint_showing or _hint_queue.is_empty():
		return
	_hint_showing = true
	var text: String = _hint_queue.pop_front()
	hint_label.text = text
	hint_label.position = _hint_base_pos + Vector2(14.0, 0.0)
	hint_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(hint_label, "position", _hint_base_pos, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(hint_label, "modulate:a", 1.0, 0.16)
	tween.tween_interval(HINT_DURATION)
	tween.tween_property(hint_label, "modulate:a", 0.0, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_hint_showing = false
		_process_hint_queue()
	)


func _append_message(who: String, text: String) -> void:
	var color := "#f2e0c0"
	if who == "主人":
		color = "#9fd0ff"
	elif who == "系统":
		color = "#ff9f9f"
	message_label.append_text("[color=%s]%s：[/color]%s\n" % [color, who, text])
