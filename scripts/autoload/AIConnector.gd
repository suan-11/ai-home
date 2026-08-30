extends Node
## AI HTTP 客户端：OpenAI 兼容 /chat/completions。
## 三种请求模式：CHAT（默认，信号回传）/ JSON / TEXT（可传 on_success/on_error 回调）。
## 不传回调时：JSON 用 json_reply，TEXT 用 text_reply，错误统一 error_occurred。

signal chat_reply(text: String)
signal text_reply(text: String)
signal json_reply(data: Dictionary)
signal error_occurred(message: String)

const CONNECT_TIMEOUT := 20.0

enum Mode { CHAT, JSON, TEXT }

var _http: HTTPRequest
var _pending := false
var _mode: int = Mode.CHAT
var _on_success: Callable = Callable()
var _on_error: Callable = Callable()


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = CONNECT_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func can_send() -> bool:
	return not _pending


func send_chat(messages: Array) -> void:
	_request(Mode.CHAT, messages, null, null)


func request_json(messages: Array, on_success = null, on_error = null) -> void:
	_request(Mode.JSON, messages, on_success, on_error)


func request_text(messages: Array, on_success = null, on_error = null) -> void:
	_request(Mode.TEXT, messages, on_success, on_error)


func _request(mode: int, messages: Array, on_success, on_error) -> void:
	if _pending:
		_fail("上一次请求还没完成，请稍等", on_error)
		return

	var api_base: String = ConfigManager.get_value("ai", "api_base", "")
	var api_key: String = ConfigManager.get_value("ai", "api_key", "")
	var model: String = ConfigManager.get_value("ai", "model", "")

	if api_base.is_empty() or api_key.is_empty():
		_fail("请先在设置 → AI 设置里填写 Base URL 和 API Key", on_error)
		return
	if model.is_empty():
		_fail("请先在设置里填写模型名", on_error)
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

	_mode = mode
	_on_success = on_success if on_success is Callable else Callable()
	_on_error = on_error if on_error is Callable else Callable()
	_pending = true
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_pending = false
		_fail("请求创建失败：%s" % error_string(err), _on_error)


func _fail(message: String, on_error) -> void:
	if on_error is Callable and on_error.is_valid():
		on_error.call(message)
	else:
		error_occurred.emit(message)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_pending = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("网络请求失败，请检查 Base URL 和网络（%s）" % error_string(result), _on_error)
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		_fail("返回数据不是有效 JSON", _on_error)
		return

	if response_code < 200 or response_code >= 300:
		var error_text := "请求失败：HTTP %d" % response_code
		if parsed is Dictionary and parsed.has("error"):
			error_text += " - " + str(parsed["error"])
		_fail(error_text, _on_error)
		return

	if parsed is Dictionary && parsed.has("choices") && parsed["choices"] is Array:
		var first = parsed["choices"][0]
		if first is Dictionary and first.has("message"):
			var message = first["message"]
			if message is Dictionary and message.has("content"):
				_dispatch(str(message["content"]))
				return

	_fail("响应格式不正确", _on_error)


func _dispatch(content: String) -> void:
	match _mode:
		Mode.JSON:
			_handle_json(content)
		Mode.TEXT:
			if _on_success.is_valid():
				_on_success.call(content)
			else:
				text_reply.emit(content)
		_:
			chat_reply.emit(content)


func _handle_json(content: String) -> void:
	var data = JSON.parse_string(content)
	if not (data is Dictionary):
		data = _extract_json(content)
	if data is Dictionary:
		if _on_success.is_valid():
			_on_success.call(data)
		else:
			json_reply.emit(data)
	else:
		print("[AIConnector] JSON 解析失败，AI 返回原文：\n", content)
		_fail("AI 返回的不是有效 JSON（已记录到控制台）", _on_error)


func _extract_json(content: String):
	var text := content.strip_edges()
	# 去掉 Markdown 代码围栏（```json 或 ```）
	text = text.replace("`json", "").replace("```", "")
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	var start := text.find("{")
	if start < 0:
		return null
	# 从第一个 { 起做括号配对，提取最外层 JSON 对象（跳过字符串里的引号与转义）
	var in_str := false
	var escaped := false
	var depth := 0
	for i in range(start, text.length()):
		var ch := text[i]
		if escaped:
			escaped = false
			continue
		if in_str and ch == "\\":
			escaped = true
			continue
		if ch == "\"":
			in_str = not in_str
			continue
		if in_str:
			continue
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				var candidate := text.substr(start, i - start + 1)
				parsed = JSON.parse_string(candidate)
				if parsed is Dictionary:
					return parsed
				return null
	return null
