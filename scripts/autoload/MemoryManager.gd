extends Node
## 记忆系统：聊天历史（短期/每日）、长期摘要、key_facts、日记。
## 数据保存到 user://memory.json；好感度状态在 GameManager。
## 摘要/日记优先用 AI 提炼，失败或无 API 时降级为规则拼接。

signal diary_updated(char_id: String, date: String)

const MEMORY_PATH := "user://memory.json"
const MAX_SHORT_TERM := 40        # 约 20 轮对话
const MAX_KEY_FACTS := 20
const SUMMARY_LIMIT := 500
const SUMMARY_BATCH := 10         # 累计多少条溢出消息触发一次提炼

var _memory: Dictionary = {}
var _summarizing := false
var _generating_diary: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	if FileAccess.file_exists(MEMORY_PATH):
		var file = FileAccess.open(MEMORY_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				_memory = parsed
				return
	_memory = {}
	_save()


func _save() -> void:
	var file = FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_memory, "\t"))
		file.close()


func today() -> String:
	return Time.get_date_string_from_system()


func get_persona_system(char_id: String) -> String:
	var path := "res://assets/chars/%s/persona.json" % char_id
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				if parsed.has("system_prompt") and str(parsed["system_prompt"]).strip_edges() != "":
					return str(parsed["system_prompt"])
				return _build_persona_from_fields(parsed)
	return "你是住在温馨房间里的AI伙伴，请用自然、简短的语气回应主人。"


## 简易人设没有 system_prompt 时，从字段拼接（新角色/未写全人设的降级）。
func _build_persona_from_fields(persona: Dictionary) -> String:
	var name := str(persona.get("display_name", persona.get("name", "AI伙伴")))
	var lines: Array[String] = ["你是%s。" % name]
	var personality := str(persona.get("personality", ""))
	if not personality.is_empty():
		lines.append("性格：%s。" % personality)
	var style := str(persona.get("speech_style", ""))
	if not style.is_empty():
		lines.append("说话风格：%s。" % style)
	var greeting := str(persona.get("greeting", ""))
	if not greeting.is_empty():
		lines.append("开场白：%s" % greeting)
	lines.append("你是住在房间里的AI角色，不知自己是AI；用自然、简短的语气回应主人。")
	return "\n".join(lines)


func _display_name(char_id: String) -> String:
	return CharacterCatalog.get_display_name(char_id)


## ---------------- 读写接口 ----------------

func get_char(char_id: String) -> Dictionary:
	if not _memory.has(char_id):
		var char_mem := _default_char_memory()
		_memory[char_id] = char_mem
		_save()
		return char_mem
	var mem: Dictionary = _memory[char_id]
	var defaults := _default_char_memory()
	for key in defaults:
		if not mem.has(key):
			mem[key] = defaults[key]
	return mem


func get_short_term(char_id: String) -> Array:
	var mem := get_char(char_id)
	return mem["short_term"]


func record_chat(char_id: String, role: String, content: String) -> void:
	var mem := get_char(char_id)
	var entry := {
		"role": role,
		"content": content,
		"time": int(Time.get_unix_time_from_system()),
	}
	var date := today()

	var daily: Dictionary = mem["daily_chats"]
	if not daily.has(date):
		daily[date] = []
	daily[date].append(entry.duplicate(true))

	var short_term: Array = mem["short_term"]
	short_term.append(entry.duplicate(true))
	if short_term.size() > MAX_SHORT_TERM:
		var overflow: Array = short_term.slice(0, short_term.size() - MAX_SHORT_TERM)
		short_term = short_term.slice(short_term.size() - MAX_SHORT_TERM)
		mem["short_term"] = short_term
		var pending: Array = mem["pending_summary"]
		for item in overflow:
			pending.append(item)
		mem["pending_summary"] = pending

	_save()
	maybe_summarize(char_id)


func record_daily_event(char_id: String, kind: String, detail: String) -> void:
	var mem := get_char(char_id)
	var date := today()
	var daily: Dictionary = mem["daily_events"]
	if not daily.has(date):
		daily[date] = []
	daily[date].append({
		"kind": kind,
		"detail": detail,
		"time": int(Time.get_unix_time_from_system()),
	})
	_save()


func get_daily_chats(char_id: String, date: String) -> Array:
	var mem := get_char(char_id)
	var daily: Dictionary = mem["daily_chats"]
	if daily.has(date):
		return daily[date]
	return []


func get_today_chats(char_id: String) -> Array:
	return get_daily_chats(char_id, today())


func get_daily_events(char_id: String, date: String) -> Array:
	var mem := get_char(char_id)
	var daily: Dictionary = mem["daily_events"]
	if daily.has(date):
		return daily[date]
	return []


func get_today_events(char_id: String) -> Array:
	return get_daily_events(char_id, today())


func get_diary(char_id: String, date: String) -> String:
	var mem := get_char(char_id)
	var diaries: Dictionary = mem["diaries"]
	if diaries.has(date):
		return str(diaries[date])
	return ""


func set_diary(char_id: String, date: String, text: String) -> void:
	var mem := get_char(char_id)
	var diaries: Dictionary = mem["diaries"]
	diaries[date] = text
	_save()
	diary_updated.emit(char_id, date)


## ---------------- 聊天上下文 ----------------

func build_chat_context(char_id: String, system_prompt: String) -> Array:
	var mem := get_char(char_id)
	var messages: Array = [{"role": "system", "content": system_prompt}]
	var memory_block := _memory_context_block(mem)
	if not memory_block.is_empty():
		messages.append({"role": "system", "content": memory_block})
	for entry in mem["short_term"]:
		if entry is Dictionary:
			messages.append({"role": entry["role"], "content": entry["content"]})
	var level := GameManager.get_affection_level(char_id)
	var rank := GameManager.get_affection_rank_name(char_id)
	var tone := "自然亲近"
	if level >= 5:
		tone = "极其亲密、如家人般依赖"
	elif level >= 3:
		tone = "亲近、会主动撒娇和依赖"
	elif level >= 2:
		tone = "熟络的好友，轻松自然"
	messages.append({
		"role": "system",
		"content": "当前%s与你的好感等级：Lv.%d「%s」（%s）。气质和话语要符合该亲近程度，但不要刻意谈论等级或数字。" % [_display_name(char_id), level, rank, tone],
	})
	return messages


func _memory_context_block(mem: Dictionary) -> String:
	var parts: Array[String] = []
	var summary := str(mem["long_term_summary"])
	if not summary.is_empty():
		parts.append("【长期记忆】%s" % summary)
	var facts: Array = mem["key_facts"]
	if not facts.is_empty():
		var lines: Array[String] = []
		for fact in facts:
			lines.append("- %s" % str(fact))
		parts.append("【重要事实】\n" + "\n".join(lines))
	return "\n".join(parts)


## ---------------- 长期摘要提炼 ----------------

func maybe_summarize(char_id: String) -> void:
	if _summarizing:
		return
	var mem := get_char(char_id)
	var pending: Array = mem["pending_summary"]
	if pending.size() < SUMMARY_BATCH:
		return
	if not AIConnector.can_send():
		return
	_summarizing = true
	var messages: Array = [
		{
			"role": "system",
			"content": "你是记忆整理助手。根据新增对话更新某角色的长期记忆摘要和值得记住的事实。要求：摘要不超过500字；事实是简洁短句，最多20条，不要与已有重复。只输出JSON：{\"summary\":\"...\",\"facts\":[\"...\"]}",
		},
		{"role": "user", "content": _pending_text(char_id)},
	]
	AIConnector.request_json(
		messages,
		_on_summary_done.bind(char_id),
		func(_message: String) -> void: _on_summary_error(char_id)
	)


func _on_summary_done(data: Dictionary, char_id: String) -> void:
	_summarizing = false
	var new_summary := str(data.get("summary", ""))
	if new_summary.is_empty():
		_apply_summary_fallback(char_id)
		return
	if new_summary.length() > SUMMARY_LIMIT:
		new_summary = new_summary.substr(0, SUMMARY_LIMIT)

	var mem := get_char(char_id)
	mem["long_term_summary"] = new_summary
	mem["last_summary_update"] = today()

	var existing: Array = mem["key_facts"]
	var raw_facts = data.get("facts", [])
	if raw_facts is Array:
		for fact in raw_facts:
			var fact_text := str(fact).strip_edges()
			if fact_text.is_empty() or fact_text in existing:
				continue
			existing.append(fact_text)
			if existing.size() >= MAX_KEY_FACTS:
				break
	mem["key_facts"] = existing
	mem["pending_summary"] = []
	_save()


func _on_summary_error(char_id: String) -> void:
	_summarizing = false
	_apply_summary_fallback(char_id)


func _apply_summary_fallback(char_id: String) -> void:
	var mem := get_char(char_id)
	var pending: Array = mem["pending_summary"]
	if pending.is_empty():
		return
	var chunks: Array[String] = []
	for item in pending:
		chunks.append("「%s」%s" % [str(item["role"]), str(item["content"])])
	var block := "\n".join(chunks)
	var current := str(mem["long_term_summary"])
	var merged := block
	if not current.is_empty():
		merged = current + "\n" + block
	if merged.length() > SUMMARY_LIMIT:
		merged = merged.substr(0, SUMMARY_LIMIT)
	mem["long_term_summary"] = merged
	mem["last_summary_update"] = today()
	mem["pending_summary"] = []
	_save()


func _pending_text(char_id: String) -> String:
	var mem := get_char(char_id)
	var parts: Array[String] = []
	var current := str(mem["long_term_summary"])
	if not current.is_empty():
		parts.append("当前摘要：\n" + current)
	var pending: Array = mem["pending_summary"]
	if not pending.is_empty():
		parts.append("新增对话：")
		for item in pending:
			parts.append("- %s：%s" % [str(item["role"]), str(item["content"])])
	return "\n".join(parts)


## ---------------- 日记 ----------------

func generate_diary(char_id: String, date: String, force := false) -> bool:
	var key := char_id + "|" + date
	if _generating_diary.has(key):
		return false
	if not force and not get_diary(char_id, date).is_empty():
		return true

	var material := _diary_material(char_id, date)
	if material.is_empty():
		set_diary(char_id, date, "《%s》\n这一天没有和主人的特别记录。" % date)
		return true

	if not AIConnector.can_send():
		set_diary(char_id, date, _fallback_diary(date, material))
		return true

	_generating_diary[key] = true
	AIConnector.request_text(
		_diary_prompt(char_id, date, material),
		_on_diary_done.bind(char_id, date),
		func(_message: String) -> void: _on_diary_error(char_id, date)
	)
	return true


func _on_diary_done(text: String, char_id: String, date: String) -> void:
	_generating_diary.erase(char_id + "|" + date)
	var clean := str(text).strip_edges()
	if clean.is_empty():
		clean = _fallback_diary(date, _diary_material(char_id, date))
	set_diary(char_id, date, clean)


func _on_diary_error(char_id: String, date: String) -> void:
	_generating_diary.erase(char_id + "|" + date)
	set_diary(char_id, date, _fallback_diary(date, _diary_material(char_id, date)))


func _diary_prompt(char_id: String, date: String, material: String) -> Array:
	var system := get_persona_system(char_id)
	system += "\n\n现在请以%s的身份，为%s写一篇当天的简短日记（90-150字）：记录和主人一起做的事、聊天内容、好感度变化。只输出日记正文，不要标题、不要引号、不要解释，语气符合人设。" % [_display_name(char_id), date]
	return [
		{"role": "system", "content": system},
		{"role": "user", "content": "今天的记录：\n" + material},
	]


func _fallback_diary(date: String, material: String) -> String:
	return "《%s》\n%s\n（好感度与记忆已记录）" % [date, material]


func _diary_material(char_id: String, date: String) -> String:
	var parts: Array[String] = []
	var chats := get_daily_chats(char_id, date)
	if not chats.is_empty():
		parts.append("【聊天记录】")
		for item in chats:
			var who := "主人" if str(item["role"]) == "user" else _display_name(char_id)
			parts.append("%s：%s" % [who, str(item["content"])])

	var events := get_daily_events(char_id, date)
	if not events.is_empty():
		parts.append("【事件】")
		for item in events:
			parts.append("- %s（%s）" % [str(item["kind"]), str(item["detail"])])

	var log := GameManager.get_daily_log(char_id, date)
	var entries: Array = log.get("entries", [])
	if not entries.is_empty():
		parts.append("【好感度变化】")
		for item in entries:
			var delta := int(item["delta"])
			var sign := "+" if delta >= 0 else ""
			parts.append("%s%d（%s）" % [sign, delta, str(item["reason"])])
	return "\n".join(parts)


func _default_char_memory() -> Dictionary:
	return {
		"short_term": [],
		"pending_summary": [],
		"daily_chats": {},
		"daily_events": {},
		"key_facts": [],
		"long_term_summary": "",
		"last_summary_update": "",
		"diaries": {},
	}
