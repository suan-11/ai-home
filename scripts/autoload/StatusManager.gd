extends Node
## P2 状态系统：饱食 / 心情 / 疲惫 + 食物状态 + 自主好感当日计数 + 离线时间戳。
## 数据保存到 user://status.json。
## 在线状态按现实时间缓慢变化（饱食 -1/30min、疲惫 +1/30min）；
## 测试倍率 general.dev_state_speed（设置→通用，测试用，正式版移除）。
## 状态值内部用 float 平滑变化，对外以整数读取。

signal status_changed

const STATUS_PATH := "user://status.json"
const CHAR_ID := "char_03"
const AUTONOMY_DAILY_CAP := 3

var _status: Dictionary = {}
var _since_save := 0.0


func _ready() -> void:
	_load()
	_ensure_defaults()


## ---------------- 数据读写 ----------------


func _load() -> void:
	if FileAccess.file_exists(STATUS_PATH):
		var file = FileAccess.open(STATUS_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				_status = parsed
				return
	_status = {}
	_save()


func _save() -> void:
	var file = FileAccess.open(STATUS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_status, "\t"))
		file.close()


func _ensure_defaults() -> void:
	var st: Dictionary = _status.get(CHAR_ID, {})
	st["satiety"] = float(st.get("satiety", 70.0))
	st["fatigue"] = float(st.get("fatigue", 30.0))
	st["mood"] = float(st.get("mood", 60.0))
	st["food"] = str(st.get("food", "none"))          # none | raw | cooked
	st["autonomy_date"] = str(st.get("autonomy_date", ""))
	st["autonomy_gain"] = int(st.get("autonomy_gain", 0))
	st["last_seen"] = float(st.get("last_seen", Time.get_unix_time_from_system()))
	_status[CHAR_ID] = st
	_save()


## ---------------- 状态值 ----------------


func get_satiety() -> int:
	return int(_status.get(CHAR_ID, {}).get("satiety", 70.0))


func get_mood() -> int:
	return int(_status.get(CHAR_ID, {}).get("mood", 60.0))


func get_fatigue() -> int:
	return int(_status.get(CHAR_ID, {}).get("fatigue", 30.0))


func get_food() -> String:
	return str(_status.get(CHAR_ID, {}).get("food", "none"))


func set_food(kind: String) -> void:
	var st: Dictionary = _status[CHAR_ID]
	var value := kind
	if value not in ["none", "raw", "cooked"]:
		value = "none"
	st["food"] = value
	_save()
	status_changed.emit()


func apply_delta(satiety: int = 0, mood: int = 0, fatigue: int = 0) -> void:
	var st: Dictionary = _status[CHAR_ID]
	st["satiety"] = clampi(int(st["satiety"]) + satiety, 0, 100)
	st["mood"] = clampi(int(st["mood"]) + mood, 0, 100)
	st["fatigue"] = clampi(int(st["fatigue"]) + fatigue, 0, 100)
	_save()
	status_changed.emit()


func apply_float_delta(satiety: float = 0.0, mood: float = 0.0, fatigue: float = 0.0) -> void:
	var st: Dictionary = _status[CHAR_ID]
	st["satiety"] = clampf(float(st["satiety"]) + satiety, 0.0, 100.0)
	st["mood"] = clampf(float(st["mood"]) + mood, 0.0, 100.0)
	st["fatigue"] = clampf(float(st["fatigue"]) + fatigue, 0.0, 100.0)
	_save()
	status_changed.emit()


func tick_online(delta: float) -> void:
	## 在线缓慢变化（现实时间口径）：饱食 -1/30min，疲惫 +1/30min。
	## 测试倍率 general.dev_state_speed（正式版移除）。
	var speed := float(ConfigManager.get_value("general", "dev_state_speed", 1))
	var st: Dictionary = _status[CHAR_ID]
	st["satiety"] = clampf(float(st["satiety"]) - delta * (1.0 / 1800.0) * speed, 0.0, 100.0)
	st["fatigue"] = clampf(float(st["fatigue"]) + delta * (1.0 / 1800.0) * speed, 0.0, 100.0)
	_since_save += delta
	if _since_save >= 30.0:
		_since_save = 0.0
		st["last_seen"] = Time.get_unix_time_from_system()
		_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		mark_seen()


## ---------------- 离线 ----------------


func get_offline_seconds() -> float:
	var st: Dictionary = _status.get(CHAR_ID, {})
	var last := float(st.get("last_seen", Time.get_unix_time_from_system()))
	return maxf(0.0, Time.get_unix_time_from_system() - last)


func mark_seen() -> void:
	var st: Dictionary = _status[CHAR_ID]
	st["last_seen"] = Time.get_unix_time_from_system()
	_save()


func apply_offline_seconds(seconds: float) -> void:
	## 按现实时间模拟离线自然变化（离线为主变化来源；倍率同样适用）。
	var speed := float(ConfigManager.get_value("general", "dev_state_speed", 1))
	apply_float_delta(
		-(seconds * (1.0 / 1800.0)) * speed,
		0.0,
		(seconds * (1.0 / 1800.0)) * speed
	)


## ---------------- 自主好感（每日 +3 上限） ----------------


func try_autonomy_affection(amount: int = 1) -> bool:
	## 自主行为 50% 概率 +1（amount 用于结算场景的 0/1 判定）；
	## 离线 AI 结算请直接用 add_autonomy_affection。
	if amount <= 0:
		return false
	if randf() > 0.5:
		return false
	return add_autonomy_affection(amount)


func add_autonomy_affection(amount: int = 1) -> bool:
	## 不受概率限制；仅受每日上限约束（离线结算也走这里）。
	var today := Time.get_date_string_from_system()
	var st: Dictionary = _status[CHAR_ID]
	if str(st.get("autonomy_date", "")) != today:
		st["autonomy_date"] = today
		st["autonomy_gain"] = 0
	var gain := int(st["autonomy_gain"])
	if gain + amount > AUTONOMY_DAILY_CAP:
		return false
	st["autonomy_gain"] = gain + amount
	_save()
	return true


func get_today_autonomy_gain() -> int:
	var today := Time.get_date_string_from_system()
	var st: Dictionary = _status[CHAR_ID]
	if str(st.get("autonomy_date", "")) != today:
		return 0
	return int(st["autonomy_gain"])


## ---------------- 提示（给聊天/离线结算用） ----------------


func get_state_summary() -> String:
	return "当前状态：饱食 %d/100（%s），疲惫 %d/100（%s），心情 %d/100（%s）" % [
		get_satiety(), _satiety_desc(),
		get_fatigue(), _fatigue_desc(),
		get_mood(), _mood_desc(),
	]


func _satiety_desc() -> String:
	var v := get_satiety()
	if v < 30:
		return "很饿，想找吃的"
	if v < 60:
		return "有点饿"
	return "还饱着"


func _fatigue_desc() -> String:
	var v := get_fatigue()
	if v > 75:
		return "非常累，想休息"
	if v > 50:
		return "有点累"
	return "精神不错"


func _mood_desc() -> String:
	var v := get_mood()
	if v < 30:
		return "心情低落"
	if v < 55:
		return "一般般"
	if v > 75:
		return "心情很好"
	return "还不错"
