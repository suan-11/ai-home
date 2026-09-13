extends Node
## AI HTTP 客户端：OpenAI 兼容 /chat/completions。
## 三种请求模式：CHAT（默认，信号回传）/ JSON / TEXT（可传 on_success/on_error 回调）。
##
## 请求进入 FIFO 队列串行发送（引擎只持有一个 HTTPRequest）：
## - 并发请求（离线结算 / 聊天 / 手机 / 日记）不再互相打断，按先后顺序排队
## - 每个任务携带自己的模式与回调，互不覆盖；错误只回传给所属请求
## - 无回调的请求失败时才发 error_occurred（供聊天窗等信号式调用方使用）
## - 配置缺失 / 请求创建失败会立即回调该任务并继续队列

signal chat_reply(text: String)
signal text_reply(text: String)
signal json_reply(data: Dictionary)
signal error_occurred(message: String)

const DEFAULT_TIMEOUT := 60.0
const MAX_QUEUE := 8

enum Mode { CHAT, JSON, TEXT }

var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _pending := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = DEFAULT_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


## 是否空闲（无在途请求、无排队）。后台任务（记忆摘要 / 日记）用它决定是否现在就发。
func can_send() -> bool:
	return not _pending and _queue.is_empty()


func send_chat(messages: Array) -> void:
	_request(Mode.CHAT, messages, null, null)


func request_json(messages: Array, on_success = null, on_error = null) -> void:
	_request(Mode.JSON, messages, on_success, on_error)


func request_text(messages: Array, on_success = null, on_error = null) -> void:
	_request(Mode.TEXT, messages, on_success, on_error)


func _request(mode: int, messages: Array, on_success, on_error) -> void:
	if _queue.size() >= MAX_QUEUE:
		_fail("请求排队已满，请稍后再试", on_error)
		return
	_queue.append({
		"mode": mode,
		"messages": messages,
		"on_success": on_success if on_success is Callable else Callable(),
		"on_error": on_error if on_error is Callable else Callable(),
	})
	_pump()


## 取出队首任务发送；配置缺失 / 创建失败时立即回调并继续处理下一个。
func _pump() -> void:
	if _pending or _queue.is_empty():
		return
	var job: Dictionary = _queue.pop_front()

	var api_base: String = ConfigManager.get_value("ai", "api_base", "")
	var api_key: String = ConfigManager.get_value("ai", "api_key", "")
	var model: String = ConfigManager.get_value("ai", "model", "")
	if api_base.is_empty() or api_key.is_empty():
		_fail_job(job, "请先在设置 → AI 设置里填写 Base URL 和 API Key")
		_pump()
		return
	if model.is_empty():
		_fail_job(job, "请先在设置里填写模型名")
		_pump()
		return

	var url := api_base.trim_suffix("/") + "/chat/completions"
	var body := JSON.stringify({
		"model": model,
		"messages": job["messages"],
		"max_tokens": int(ConfigManager.get_value("ai", "max_tokens", 512)),
		"temperature": float(ConfigManager.get_value("ai", "temperature", 0.8)),
	})
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	]

	_current = job
	_pending = true
	_http.timeout = maxf(float(ConfigManager.get_value("ai", "timeout_seconds", DEFAULT_TIMEOUT)), 5.0)
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_pending = false
		_current = {}
		_fail_job(job, "请求创建失败：%s" % error_string(err))
		_pump()


func _fail(message: String, on_error) -> void:
	if on_error is Callable and on_error.is_valid():
		on_error.call(message)
	else:
		error_occurred.emit(message)


func _fail_job(job: Dictionary, message: String) -> void:
	var on_error: Callable = job.get("on_error", Callable())
	if on_error.is_valid():
		on_error.call(message)
	else:
		error_occurred.emit(message)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var job := _current
	_current = {}
	_pending = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_fail_job(job, "网络请求失败，请检查 Base URL 和网络（%s）" % error_string(result))
		_pump()
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		_fail_job(job, "返回数据不是有效 JSON")
		_pump()
		return

	if response_code < 200 or response_code >= 300:
		var error_text := "请求失败：HTTP %d" % response_code
		if parsed is Dictionary and parsed.has("error"):
			error_text += " - " + str(parsed["error"])
		_fail_job(job, error_text)
		_pump()
		return

	if parsed is Dictionary && parsed.has("choices") && parsed["choices"] is Array:
		var first = parsed["choices"][0]
		if first is Dictionary and first.has("message"):
			var message = first["message"]
			if message is Dictionary and message.has("content"):
				_dispatch(job, str(message["content"]))
				_pump()
				return

	_fail_job(job, "响应格式不正确")
	_pump()


func _dispatch(job: Dictionary, content: String) -> void:
	match int(job.get("mode", Mode.CHAT)):
		Mode.JSON:
			_handle_json(job, content)
		Mode.TEXT:
			var on_success: Callable = job.get("on_success", Callable())
			if on_success.is_valid():
				on_success.call(content)
			else:
				text_reply.emit(content)
		_:
			chat_reply.emit(content)


func _handle_json(job: Dictionary, content: String) -> void:
	var data = JSON.parse_string(content)
	if not (data is Dictionary):
		data = _extract_json(content)
	if data is Dictionary:
		var on_success: Callable = job.get("on_success", Callable())
		if on_success.is_valid():
			on_success.call(data)
		else:
			json_reply.emit(data)
	else:
		print("[AIConnector] JSON 解析失败，AI 返回原文：\n", content)
		_fail_job(job, "AI 返回的不是有效 JSON（已记录到控制台）")


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
