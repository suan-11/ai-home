class_name CharacterInteractions
extends RefCounted
## 从角色文件读取互动配置：res://assets/chars/<char_id>/interactions.json
##
## 文件结构（每个键 = 一个互动 id）：
## {
##   "pet": {
##     "name": "摸摸头",              # 显示名
##     "entry": "character",          # 入口：character=点击角色菜单；furniture:<交互名>=家具交互
##     "actions": ["hop"],            # 交互动作（wave/hop/sad）
##     "expression": "shy",           # 立绘表情（见 portrait_manager）
##     "expression_duration": 2.5,
##     "texts": ["手拿开喵。"],       # 随机出一句气泡
##     "reply_delay": 0.6,            # 气泡延迟
##     "effects": {"mood": 3},        # 状态效果：satiety/mood/fatigue
##     "affection": {"amount": 1, "reason": "摸摸头"},
##     "limits": {"daily": 5}         # daily=每日次数；cooldown=秒
##   }
## }

static func load_specs(char_id: String) -> Dictionary:
	var path := "res://assets/chars/%s/interactions.json" % char_id
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
