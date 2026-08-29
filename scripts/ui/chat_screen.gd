extends Control
## 聊天应用：与梅尔对话，接入 AIConnector（OpenAI 兼容接口）。

signal back_requested

var _messages: Array = []
var _waiting := false

@onready var message_label: RichTextLabel = $ScrollContainer/MessageLabel
@onready var input_edit: LineEdit = $BottomBar/InputEdit
@onready var send_button: Button = $BottomBar/SendButton


func _ready() -> void:
	_load_persona()
	AIConnector.chat_reply.connect(_on_chat_reply)
	AIConnector.error_occurred.connect(_on_chat_error)
	$BackButton.pressed.connect(_on_back_pressed)
	send_button.pressed.connect(_on_send_pressed)
	input_edit.text_submitted.connect(func(_text: String) -> void: _on_send_pressed())


func _draw() -> void:
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.20, 0.16, 0.20, 0.98))
	draw_rect(Rect2(Vector2(4, 4), Vector2(size.x - 8, 30)), Color(0.16, 0.13, 0.18))


func _load_persona() -> void:
	var file = FileAccess.open("res://assets/chars/char_03/persona.json", FileAccess.READ)
	var system_prompt := "你是梅尔·艾什礼佩克，来自《霞流宝石心》世界的猫形兽人，天马班首席。"
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary and parsed.has("system_prompt"):
			system_prompt = str(parsed["system_prompt"])
	_messages.clear()
	_messages.append({"role": "system", "content": system_prompt})
	_append_message("梅尔", "数据呢喵。说正事喵。")


func _on_send_pressed() -> void:
	if _waiting:
		return
	var text := input_edit.text.strip_edges()
	if text.is_empty():
		return
	input_edit.text = ""
	_append_message("主人", text)
	_messages.append({"role": "user", "content": text})
	_waiting = true
	send_button.disabled = true
	input_edit.editable = false
	AIConnector.send_chat(_messages)


func _on_chat_reply(text: String) -> void:
	_waiting = false
	send_button.disabled = false
	input_edit.editable = true
	_messages.append({"role": "assistant", "content": text})
	_append_message("梅尔", text)


func _on_chat_error(message: String) -> void:
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
