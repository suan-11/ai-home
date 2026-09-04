class_name CharacterCatalog
extends RefCounted
## 角色发现与元数据读取：扫描 res://assets/chars/<char_id>/ 下的角色目录。
##
## 可用判定（基础素材）：目录内同时存在
##   - persona.json（人设）
##   - portrait.png（立绘原图）
##   - sprites/（至少 idle_0.png 或 walk_0.png 之一）
## 满足即可进入切换列表；差分立绘（portraits/）与互动（interactions.json）
## 为可选，缺失时由运行时降级（立绘用单张原图、无互动菜单）。

const CHARS_ROOT := "res://assets/chars"
const KNOWN_PORTRAIT_KINDS := [
	"default", "happy", "low", "shy", "distracted", "surprised", "angry", "blushing_worried",
]


## 列出所有可用角色（按 persona.order 升序，未设置 order 的排后面）。
static func list_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(CHARS_ROOT)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with(".") and not entry.begins_with("_"):
			if is_available(entry):
				result.append(get_character_info(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 99)) < int(b.get("order", 99))
	)
	return result


## 角色是否具备基础素材（可进入切换列表）。
static func is_available(char_id: String) -> bool:
	if char_id.is_empty():
		return false
	var dir_path := "%s/%s" % [CHARS_ROOT, char_id]
	return (
		FileAccess.file_exists(dir_path + "/persona.json")
		and FileAccess.file_exists(dir_path + "/portrait.png")
		and (
			FileAccess.file_exists(dir_path + "/sprites/idle_0.png")
			or FileAccess.file_exists(dir_path + "/sprites/walk_0.png")
		)
	)


## 读取角色目录元数据（供切换列表/UI 展示）。
static func get_character_info(char_id: String) -> Dictionary:
	var persona := get_persona(char_id)
	var dir_path := "%s/%s" % [CHARS_ROOT, char_id]
	var has_portraits := FileAccess.file_exists(dir_path + "/portraits/default.png")
	var has_interactions := FileAccess.file_exists(dir_path + "/interactions.json")
	return {
		"id": char_id,
		"name": str(persona.get("display_name", persona.get("name", char_id))),
		"display_name": str(persona.get("display_name", persona.get("name", char_id))),
		"personality": str(persona.get("personality", "")),
		"greeting": str(persona.get("greeting", "")),
		"portrait_path": get_portrait_path(char_id),
		"has_portraits": has_portraits,
		"has_interactions": has_interactions,
		"order": int(persona.get("order", 99)),
	}


## 读取 persona.json；不存在返回空字典。
static func get_persona(char_id: String) -> Dictionary:
	var path := "%s/%s/persona.json" % [CHARS_ROOT, char_id]
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


## 显示名：display_name > name > 角色 id。
static func get_display_name(char_id: String) -> String:
	var persona := get_persona(char_id)
	return str(persona.get("display_name", persona.get("name", char_id))).strip_edges()


## 立绘路径：优先 portraits/default.png（差分档），否则 portrait.png（单张原图）。
static func get_portrait_path(char_id: String) -> String:
	var dir_path := "%s/%s" % [CHARS_ROOT, char_id]
	if FileAccess.file_exists(dir_path + "/portraits/default.png"):
		return dir_path + "/portraits/default.png"
	if FileAccess.file_exists(dir_path + "/portrait.png"):
		return dir_path + "/portrait.png"
	return ""


## 指定表情的立绘路径；缺失时回落到单张原图。
static func get_expression_path(char_id: String, kind: String) -> String:
	var dir_path := "%s/%s" % [CHARS_ROOT, char_id]
	if kind in KNOWN_PORTRAIT_KINDS and FileAccess.file_exists(dir_path + "/portraits/" + kind + ".png"):
		return dir_path + "/portraits/" + kind + ".png"
	return get_portrait_path(char_id)
