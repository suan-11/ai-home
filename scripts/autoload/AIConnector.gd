extends Node
## AI HTTP 客户端：调用 OpenAI 兼容 /chat/completions 接口。
## 配置来源：ConfigManager（设置界面 AI 标签页）。

signal chat_reply(text: String)
signal error_occurred(message: String)

const CONNECT_TIMEOUT := 20.0

var _http: HTTPRequest
var _pending := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = CONNECT_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func can_send() -> bool:
	return not _pending


func send_chat(messages: Array) -> void:
	if _pending:
		error_occurred.emit("上一次请求还没完成，请稍等喵")
		return

	var api_base: String = ConfigManager.get_value("ai", "api_base", "")
	var api_key: String = ConfigManager.get_value("ai", "api_key", "")
	var model: String = ConfigManager.get_value("ai", "model", "")

	if api_base.is_empty() or api_key.is_empty():
		error_occurred.emit("请先在设置 → AI 设置里填写 Base URL 和 API Key")
		return
	if model.is_empty():
		error_occurred.emit("请先在设置里填写模型名")
		return

	var url := api_base.trim_suffix("/") + "/chat/completions"
	var body := JSON.stringify({
		"model": model,
		"messages": messages,
		"max_tokens": int(ConfigManager.get_value("ai", "max_tokens", 512)),
		"temperature": float(ConfigManager.get_value("ai", "temperature", 0.8)),
	})

	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	]

	_pending = true
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_pending = false
		error_occurred.emit("请求创建失败：%s" % error_string(err))


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_pending = false

	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络请求失败，请检查 Base URL 和网络（%s）" % error_string(result))
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		error_occurred.emit("返回数据不是有效 JSON")
		return

	if response_code < 200 or response_code >= 300:
		var error_text := "请求失败：HTTP %d" % response_code
		if parsed is Dictionary and parsed.has("error"):
			error_text += " - " + str(parsed["error"])
		error_occurred.emit(error_text)
		return

	if parsed is Dictionary && parsed.has("choices") && parsed["choices"] is Array:
		var first = parsed["choices"][0]
		if first is Dictionary and first.has("message"):
			var message = first["message"]
			if message is Dictionary and message.has("content"):
				var reply: String = str(message["content"])
				chat_reply.emit(reply)
				return

	error_occurred.emit("响应格式不正确")
