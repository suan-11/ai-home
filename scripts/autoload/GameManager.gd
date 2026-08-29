extends Node
## 全局角色状态：好感度（0-100）与每日变化记录。
## 数据保存到 user://game.json。

signal affection_changed(char_id: String, value: int, reason: String)

const GAME_PATH := "user://game.json"
const CHAT_DAILY_CAP := 10
const DEFAULT_AFFECTION := 50
const CURRENT_CHAR_ID := "char_03"

var _game: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	if FileAccess.file_exists(GAME_PATH):
		var file = FileAccess.open(GAME_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				_game = parsed
				return
	_game = {}
	_save()


func _save() -> void:
	var file = FileAccess.open(GAME_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_game, "\t"))
		file.close()


func today() -> String:
	return Time.get_date_string_from_system()


func get_affection(char_id: String) -> int:
	var char_data := _get_char(char_id)
	return int(char_data.get("affection", DEFAULT_AFFECTION))


func get_daily_log(char_id: String, date: String) -> Dictionary:
	var char_data := _get_char(char_id)
	var daily: Dictionary = char_data["daily"]
	if daily.has(date):
		return daily[date]
	return {"chat_gain": 0, "entries": []}


func get_today_chat_gain(char_id: String) -> int:
	var log := get_daily_log(char_id, today())
	return int(log.get("chat_gain", 0))


func add_affection(char_id: String, delta: int, reason: String, source: String) -> int:
	if delta == 0:
		return 0
	var char_data := _get_char(char_id)
	var old := int(char_data.get("affection", DEFAULT_AFFECTION))
	var new_value := clampi(old + delta, 0, 100)
	var applied := new_value - old
	if applied == 0:
		return 0

	char_data["affection"] = new_value
	var date := today()
	var daily: Dictionary = char_data["daily"]
	if not daily.has(date):
		daily[date] = {"chat_gain": 0, "entries": []}
	var log: Dictionary = daily[date]
	if not log.has("entries"):
		log["entries"] = []
	log["entries"].append({
		"source": source,
		"delta": applied,
		"reason": reason,
		"time": int(Time.get_unix_time_from_system()),
	})
	_save()
	affection_changed.emit(char_id, new_value, reason)
	return applied


func add_chat_affection(char_id: String, eligible: bool, reason: String) -> bool:
	if not eligible:
		return false
	var char_data := _get_char(char_id)
	var date := today()
	var daily: Dictionary = char_data["daily"]
	if not daily.has(date):
		daily[date] = {"chat_gain": 0, "entries": []}
	var log: Dictionary = daily[date]
	var gain := int(log.get("chat_gain", 0))
	if gain >= CHAT_DAILY_CAP:
		return false
	var applied := add_affection(char_id, 1, reason, "chat")
	if applied <= 0:
		return false
	log["chat_gain"] = gain + 1
	_save()
	return true


func register_interaction(char_id: String, interaction_name: String) -> bool:
	var char_data := _get_char(char_id)
	var date := today()
	var interactions: Dictionary = char_data["interactions"]
	if not interactions.has(date):
		interactions[date] = {}
	var today_interactions: Dictionary = interactions[date]
	if today_interactions.has(interaction_name):
		return false
	today_interactions[interaction_name] = true
	var applied := add_affection(char_id, 1, "交互：%s" % interaction_name, "interaction")
	_save()
	return applied > 0


func on_game_finished(char_id: String, result: String) -> int:
	var delta := 0
	var reason := ""
	match result:
		"win":
			delta = 3
			reason = "和主人下五子棋，主人赢了"
		"draw":
			delta = 1
			reason = "和主人下五子棋，平局"
		"lose":
			delta = 0
			reason = "和主人下五子棋，主人输了"
	if delta > 0:
		add_affection(char_id, delta, reason, "gomoku")
	return delta


func _get_char(char_id: String) -> Dictionary:
	if not _game.has("characters"):
		_game["characters"] = {}
	var chars: Dictionary = _game["characters"]
	if not chars.has(char_id):
		chars[char_id] = {
			"affection": DEFAULT_AFFECTION,
			"daily": {},
			"interactions": {},
		}
		_save()
	return chars[char_id]
