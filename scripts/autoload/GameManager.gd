extends Node
## 全局角色状态：好感度（0-100）与每日变化记录。
## 数据保存到 user://game.json。

signal affection_changed(char_id: String, value: int, reason: String)
signal current_char_changed(char_id: String)

const GAME_PATH := "user://game.json"
const CHAT_DAILY_CAP := 10
const DEFAULT_AFFECTION := 50
const DEFAULT_CHAR_ID := "char_03"

## 当前角色 id（保留原名以兼容旧引用；统一用 get_current_char_id() 读取）。
var CURRENT_CHAR_ID: String = DEFAULT_CHAR_ID

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
				var saved := str(_game.get("current_char_id", DEFAULT_CHAR_ID))
				CURRENT_CHAR_ID = saved if CharacterCatalog.is_available(saved) else DEFAULT_CHAR_ID
				return
	_game = {}
	_save()


func _save() -> void:
	var file = FileAccess.open(GAME_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_game, "\t"))
		file.close()


## ---------------- 当前角色（多角色切换） ----------------


func get_current_char_id() -> String:
	return CURRENT_CHAR_ID


## 切换当前角色：校验可用性、持久化并广播信号。
func set_current_char_id(char_id: String) -> bool:
	if not CharacterCatalog.is_available(char_id):
		return false
	if char_id == CURRENT_CHAR_ID:
		return true
	CURRENT_CHAR_ID = char_id
	_game["current_char_id"] = char_id
	_save()
	current_char_changed.emit(char_id)
	return true


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


## ---------------- 数据驱动互动使用记录（每日次数 / 冷却） ----------------


func get_interaction_usage(char_id: String, interaction_id: String) -> Dictionary:
	var char_data := _get_char(char_id)
	var usage: Dictionary = char_data.get("usage", {})
	var rec: Dictionary = usage.get(interaction_id, {})
	return rec


func record_interaction_usage(char_id: String, interaction_id: String) -> void:
	var char_data := _get_char(char_id)
	var usage: Dictionary = char_data.get("usage", {})
	var date := today()
	var rec: Dictionary = usage.get(interaction_id, {})
	if str(rec.get("date", "")) != date:
		rec = {"date": date, "count": 0, "last": 0.0}
	rec["count"] = int(rec.get("count", 0)) + 1
	rec["last"] = Time.get_unix_time_from_system()
	usage[interaction_id] = rec
	char_data["usage"] = usage
	_save()


func on_game_finished(char_id: String, result: String, game: String = "五子棋") -> int:
	var delta := 0
	var reason := ""
	match result:
		"win":
			delta = 3
			reason = "和主人下%s，主人赢了" % game
		"draw":
			delta = 1
			reason = "和主人下%s，平局" % game
		"lose":
			delta = 0
			reason = "和主人下%s，主人输了" % game
	if delta > 0:
		add_affection(char_id, delta, reason, "game")
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
			"usage": {},
		}
		_save()
	return chars[char_id]
