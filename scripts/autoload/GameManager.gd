extends Node
## 全局角色状态：好感等级系统（EXP 累积，无上限）与每日变化记录。
## 数据保存到 user://game.json。
## 2026-09-05：由 0-100 好感度改为「好感等级」——Lv1 朋友 → Lv6 家人；
## 起点即「朋友」等级（新角色默认 EXP=110），旧存档自动迁移（旧值 ×6、保底 110），不再从陌生开始。

signal affection_changed(char_id: String, value: int, reason: String)
signal affection_level_up(char_id: String, level: int)
signal current_char_changed(char_id: String)

const GAME_PATH := "user://game.json"
const CHAT_DAILY_CAP := 10
## 起始好感 EXP = Lv1「朋友」门槛（用户要求：开档至少是朋友，不从陌生开始）
const DEFAULT_AFFECTION := 110
const DEFAULT_CHAR_ID := "char_03"

## 好感等级表（2026-09-05；起点=朋友）
## 累计 EXP 阈值；日常约 12~20 EXP/天 → Lv3 约 2 周、Lv6 约 2.5~3 个月，形成成长粘性。
const RANK_NAMES: Array[String] = ["朋友", "好友", "亲近", "知心", "挚友", "家人"]
const RANK_THRESHOLDS: Array[int] = [110, 240, 430, 700, 1100, 1700]
## 旧存档（affection 0-100）→ EXP 的换算倍率：旧 50 ≈ 300 EXP ≈ Lv2 中段；迁移保底 Lv1「朋友」。
const LEGACY_AFFECTION_TO_EXP := 6

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


## ---------------- 好感等级（EXP + Lv1~Lv8） ----------------

func get_affection(char_id: String) -> int:
	## 兼容旧调用：返回当前好感 EXP 值。
	return get_affection_exp(char_id)


func get_affection_exp(char_id: String) -> int:
	var char_data := _get_char(char_id)
	return int(char_data.get("affection_exp", 0))


func get_affection_level(char_id: String) -> int:
	return _level_for_exp(get_affection_exp(char_id))


func get_affection_rank_name(char_id: String) -> String:
	return RANK_NAMES[get_affection_level(char_id) - 1]


## 下一级所需累计 EXP；已满级返回 0。
func get_affection_next_exp(char_id: String) -> int:
	var level := get_affection_level(char_id)
	if level >= RANK_THRESHOLDS.size():
		return 0
	return RANK_THRESHOLDS[level]


## 当前等级内进度 0.0~1.0（满级恒为 1.0）。
func get_affection_progress(char_id: String) -> float:
	var level := get_affection_level(char_id)
	if level >= RANK_THRESHOLDS.size():
		return 1.0
	var exp := get_affection_exp(char_id)
	var prev := RANK_THRESHOLDS[level - 1]
	var span := RANK_THRESHOLDS[level] - prev
	if span <= 0:
		return 1.0
	return clampf(float(exp - prev) / float(span), 0.0, 1.0)


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
	var old_exp := int(char_data.get("affection_exp", 0))
	var old_level := _level_for_exp(old_exp)
	var new_exp := maxi(old_exp + delta, 0)  # 无上限（等级系统），仅防负数
	var applied := new_exp - old_exp
	if applied == 0:
		return 0

	char_data["affection_exp"] = new_exp
	char_data["affection"] = new_exp  # 兼容旧字段读取
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
	affection_changed.emit(char_id, new_exp, reason)
	var new_level := _level_for_exp(new_exp)
	if new_level > old_level:
		affection_level_up.emit(char_id, new_level)
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
			"affection_exp": DEFAULT_AFFECTION,
			"daily": {},
			"interactions": {},
			"usage": {},
		}
		_save()
	var char_data: Dictionary = chars[char_id]
	# 旧存档迁移：仅有 affection(0-100) 时换算为 EXP（换算后保底「朋友」等级）
	if not char_data.has("affection_exp"):
		var legacy := int(char_data.get("affection", DEFAULT_AFFECTION))
		char_data["affection_exp"] = maxi(legacy * LEGACY_AFFECTION_TO_EXP, DEFAULT_AFFECTION)
		_save()
	return char_data


func _level_for_exp(exp: int) -> int:
	var level := 1
	for i in range(RANK_THRESHOLDS.size()):
		if exp >= RANK_THRESHOLDS[i]:
			level = i + 1
	return level
