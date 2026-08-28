extends Node
## AI HTTP 客户端（预留接口）。
## 后续在这里接入 OpenAI 兼容 API：
## 1. 从 ConfigManager 读取 api_base / api_key / model
## 2. 使用 HTTPRequest 发起 POST /chat/completions
## 3. 解析响应并通过 signal 返回给 UI

signal response_received(response: Dictionary)
signal error_occurred(message: String)


func send_chat(messages: Array) -> void:
	## 预留接口：游戏/聊天模块后续统一通过这里发消息。
	## messages 结构建议：
	## [{ "role": "system", "content": "..." }, { "role": "user", "content": "..." }]
	print("[AIConnector] send_chat reserved, messages=", messages)
	# TODO: 这里实现真实的 HTTP 请求
