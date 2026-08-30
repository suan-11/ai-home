extends Node
## 配置读写（保存到 user://config.json）。

const CONFIG_PATH := "user://config.json"

var _config: Dictionary = {}


func _ready() -> void:
	load_config()


func load_config() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				_config = parsed
				return
	_config = _default_config()
	save_config()


func save_config() -> void:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_config, "\t"))
		file.close()


func get_value(section: String, key: String, default = null):
	var section_data = _config.get(section)
	if section_data is Dictionary and section_data.has(key):
		return section_data[key]
	return default


func set_value(section: String, key: String, value) -> void:
	if not _config.has(section) or not (_config[section] is Dictionary):
		_config[section] = {}
	_config[section][key] = value
	save_config()


func get_section(section: String) -> Dictionary:
	var value = _config.get(section)
	if value is Dictionary:
		return value
	return {}


func _default_config() -> Dictionary:
	return {
		"general": {
			"owner_name": "主人",
			"auto_save": true,
			"attract_item": "random",
		},
		"display": {
			"pixel_scale": 2,
			"show_fps": false,
			"start_fullscreen": false,
		},
		"audio": {
			"bgm_volume": 0.6,
			"sfx_volume": 0.8,
			"muted": false,
		},
		"ai": {
			"api_base": "https://api.deepseek.com/v1",
			"api_key": "",
			"model": "deepseek-chat",
			"max_tokens": 512,
			"temperature": 0.8,
		},
	}
