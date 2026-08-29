extends Node2D
## Phase 1 主场景：
## - 温馨配色房间：墙面、木地板、家具
## - 家具碰撞阻挡，角色无法穿过床/桌/灯
## - 点击家具：若已在旁边则触发交互，否则走到附近空位
## - 点击地板则正常寻路，显示目标标记和路径

const GRID_SIZE := Vector2i(16, 12)
const CELL_SIZE := 16
const GRID_ORIGIN := Vector2(160, 84)
const WALL_HEIGHT := 48.0
const HALF_CELL := Vector2(8, 8)
const COMPUTER_PANEL_SCENE := preload("res://scenes/ui/computer_panel.tscn")
const SETTINGS_OVERLAY_SCENE := preload("res://scenes/ui/main_settings_overlay.tscn")
const LAYOUT_OVERLAY_SCENE := preload("res://scenes/ui/room_layout_overlay.tscn")
const HELP_OVERLAY_SCENE := preload("res://scenes/ui/help_overlay.tscn")
const LAYOUT_PATH := "user://room_layout.json"

## 家具规格表（id / 显示名 / 交互名 / 功能说明 / 尺寸 / 默认位置 / 布置网格用颜色）
const FURNITURE_SPECS := [
	{"id": "bed", "name": "床", "interaction": "sleep", "desc": "睡觉休息。当前为预留交互：触发后记录到日记并 +1 好感（每种家具每天首次）。", "size": Vector2i(2, 2), "pos": Vector2i(10, 1), "color": Color(0.62, 0.42, 0.28)},
	{"id": "desk", "name": "电脑", "interaction": "computer", "desc": "打开仿电脑操作系统：游戏选择、AI 五子棋、聊天、日记都在里面。", "size": Vector2i(2, 1), "pos": Vector2i(3, 4), "color": Color(0.55, 0.38, 0.25)},
	{"id": "shelf", "name": "书架", "interaction": "read", "desc": "阅读。当前为预留交互：触发后记录到日记并 +1 好感（每种家具每天首次）。", "size": Vector2i(2, 1), "pos": Vector2i(5, 1), "color": Color(0.45, 0.30, 0.20)},
	{"id": "chair", "name": "椅子", "interaction": "sit", "desc": "坐下。当前为预留交互：触发后记录到日记并 +1 好感（每种家具每天首次）。", "size": Vector2i(1, 1), "pos": Vector2i(5, 4), "color": Color(0.55, 0.38, 0.25)},
	{"id": "tv", "name": "电视柜", "interaction": "watch", "desc": "看电视。当前为预留交互：触发后记录到日记并 +1 好感（每种家具每天首次）。", "size": Vector2i(2, 1), "pos": Vector2i(13, 1), "color": Color(0.62, 0.43, 0.27)},
	{"id": "sofa", "name": "沙发", "interaction": "rest", "desc": "休息。当前为预留交互：触发后记录到日记并 +1 好感（每种家具每天首次）。", "size": Vector2i(2, 1), "pos": Vector2i(13, 5), "color": Color(0.78, 0.48, 0.45)},
	{"id": "lamp", "name": "落地灯", "interaction": "light", "desc": "开灯/阅读。当前为预留交互：触发后记录到日记并 +1 好感（每种家具每天首次）。", "size": Vector2i(1, 1), "pos": Vector2i(12, 8), "color": Color(1.0, 0.87, 0.58)},
	{"id": "plant", "name": "盆栽", "interaction": "water", "desc": "浇水。当前为预留交互：触发后记录到日记并 +1 好感（每种家具每天首次）。", "size": Vector2i(1, 1), "pos": Vector2i(14, 10), "color": Color(0.45, 0.65, 0.40)},
	{"id": "layout", "name": "布置台", "interaction": "decorate", "desc": "打开房间布置界面：长按家具拾起→移动→点击放下，可保存到 user://room_layout.json 或恢复默认。该交互不加好感度。", "size": Vector2i(1, 1), "pos": Vector2i(2, 10), "color": Color(0.85, 0.70, 0.45)},
]

var _target_cell: Vector2i = Vector2i(-1, -1)
var _computer_panel: Control = null
var _settings_overlay: Control = null
var _layout_overlay: Control = null
var _help_overlay: Control = null
var _pending_guide := false
var _blocked_cells: Dictionary = {}
var _furniture_list: Array = []
var _layout_objects: Array = []

@onready var character: CharacterBody2D = $Room/Character
@onready var status_label: Label = $UI/StatusLabel


func _ready() -> void:
	_load_layout()
	_blocked_cells = _build_blocked_cells()
	character.set_blocked_cells(_blocked_cells)
	character.set_grid(GRID_ORIGIN, GRID_SIZE)
	character.state_changed.connect(_on_state_changed)
	character.interaction_triggered.connect(_on_character_interaction)
	_computer_panel = COMPUTER_PANEL_SCENE.instantiate()
	$UI.add_child(_computer_panel)
	_computer_panel.closed.connect(_on_computer_panel_closed)

	_settings_overlay = SETTINGS_OVERLAY_SCENE.instantiate()
	$UI.add_child(_settings_overlay)
	_settings_overlay.closed.connect(_on_settings_overlay_closed)
	$UI/SettingsButton.pressed.connect(_on_main_settings_pressed)
	$UI/FurnitureButton.pressed.connect(_on_furniture_help_pressed)

	status_label.text = "温馨小屋：点击地板移动，F11 切换全屏"
	queue_redraw()

	# 首次进入：自动弹出新手攻略
	if not ConfigManager.get_value("general", "guide_seen", false):
		_open_help_overlay("guide")

	# 启动后自动演示一次：走向书桌旁边的空地
	await get_tree().create_timer(0.6).timeout
	_target_cell = Vector2i(5, 6)
	character.move_to_cell(_target_cell)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F11:
				_toggle_fullscreen()
				return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var cell := _pixel_to_cell(event.position)
			if not _inside_grid(cell):
				return
			var furniture := _get_furniture_at(cell)
			if not furniture.is_empty():
				_handle_furniture_click(furniture)
				return
			_target_cell = cell
			character.move_to_cell(cell)
			status_label.text = "目标：格子 %s" % str(cell)


func _on_main_settings_pressed() -> void:
	if _settings_overlay != null:
		_settings_overlay.open_overlay()


func _on_settings_overlay_closed() -> void:
	status_label.text = "设置已关闭"


func _on_furniture_help_pressed() -> void:
	_open_help_overlay("furniture")


func _open_help_overlay(mode: String) -> void:
	if _help_overlay == null:
		_help_overlay = HELP_OVERLAY_SCENE.instantiate()
		$UI.add_child(_help_overlay)
		_help_overlay.closed.connect(_on_help_overlay_closed)
	if mode == "guide":
		_pending_guide = true
		_help_overlay.setup_guide()
	else:
		_pending_guide = false
		_help_overlay.setup_furniture(FURNITURE_SPECS)
	_help_overlay.open_overlay()


func _on_help_overlay_closed() -> void:
	if _pending_guide:
		_pending_guide = false
		ConfigManager.set_value("general", "guide_seen", true)
	status_label.text = "攻略已关闭"


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen: bool = (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_character_interaction(interaction_name: String) -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	MemoryManager.record_daily_event(char_id, "interaction", interaction_name)
	if interaction_name == "computer":
		_open_computer_panel()
		return
	if interaction_name == "decorate":
		# 布置台：弹出自定义界面；不加好感度（与其它家具交互不同）
		_open_layout_overlay()
		return
	var added := GameManager.register_interaction(char_id, interaction_name)
	if added:
		status_label.text = "触发交互：%s（好感 +1）" % interaction_name
	else:
		status_label.text = "触发交互：%s" % interaction_name


func _open_computer_panel() -> void:
	if _computer_panel != null:
		_computer_panel.open_panel()


func _on_computer_panel_closed() -> void:
	status_label.text = "电脑桌已关闭"


func _handle_furniture_click(furniture: Dictionary) -> void:
	if _is_adjacent_to_furniture(character.current_cell, furniture["cells"]):
		_target_cell = Vector2i(-1, -1)
		character.trigger_interaction(furniture["interaction"])
		status_label.text = "触发交互：%s" % furniture["interaction"]
	else:
		var target := _find_nearest_free_cell_near_furniture(furniture["cells"])
		if target.x >= 0:
			_target_cell = target
			character.move_to_cell(target)
			status_label.text = "走到%s旁边" % furniture["type"]
		else:
			status_label.text = "附近没有可站立的位置"


func _build_blocked_cells() -> Dictionary:
	var blocked: Dictionary = {}
	_furniture_list.clear()
	for spec in FURNITURE_SPECS:
		_add_furniture(
			blocked,
			spec["name"],
			spec["interaction"],
			_furniture_pos(spec["id"]),
			spec["size"]
		)
	return blocked


func _add_furniture(
	blocked: Dictionary,
	type_name: String,
	interaction: String,
	cell: Vector2i,
	size: Vector2i
) -> void:
	var cells: Array = []
	for y in range(size.y):
		for x in range(size.x):
			var c := cell + Vector2i(x, y)
			blocked[c] = true
			cells.append(c)
	_furniture_list.append({
		"type": type_name,
		"interaction": interaction,
		"cells": cells,
	})


## ---------------- 房间布局（user://room_layout.json） ----------------

func _load_layout() -> void:
	_layout_objects = []
	if FileAccess.file_exists(LAYOUT_PATH):
		var file = FileAccess.open(LAYOUT_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary and parsed.has("objects") and parsed["objects"] is Array:
				for obj in parsed["objects"]:
					if not (obj is Dictionary):
						continue
					var type_id := str(obj.get("type", ""))
					var pos_data = obj.get("pos", [])
					if type_id.is_empty() or not (pos_data is Array) or pos_data.size() != 2:
						continue
					if _layout_has_type(type_id):
						continue
					_layout_objects.append({
						"type": type_id,
						"pos": Vector2i(int(pos_data[0]), int(pos_data[1])),
					})
	if _layout_objects.is_empty():
		_layout_objects = _default_layout_objects()


func _default_layout_objects() -> Array:
	var result: Array = []
	for spec in FURNITURE_SPECS:
		result.append({"type": spec["id"], "pos": spec["pos"]})
	return result


func _save_layout_objects(objects: Array) -> void:
	var json_objects: Array = []
	for obj in objects:
		json_objects.append({
			"type": str(obj["type"]),
			"pos": [int(obj["pos"].x), int(obj["pos"].y)],
		})
	var file = FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"objects": json_objects}, "\t"))
		file.close()


func _layout_has_type(type_id: String) -> bool:
	for obj in _layout_objects:
		if str(obj["type"]) == type_id:
			return true
	return false


func _furniture_pos(type_id: String) -> Vector2i:
	for obj in _layout_objects:
		if str(obj["type"]) == type_id:
			return obj["pos"]
	var spec := _spec_by_id(type_id)
	if not spec.is_empty():
		return spec["pos"]
	return Vector2i.ZERO


func _spec_by_id(type_id: String) -> Dictionary:
	for spec in FURNITURE_SPECS:
		if str(spec["id"]) == type_id:
			return spec
	return {}


func _layout_overlay_data() -> Array:
	var result: Array = []
	for obj in _layout_objects:
		var spec := _spec_by_id(str(obj["type"]))
		if spec.is_empty():
			continue
		result.append({
			"type": spec["id"],
			"name": spec["name"],
			"pos": obj["pos"],
			"size": spec["size"],
			"color": spec["color"],
		})
	return result


func _open_layout_overlay() -> void:
	if _layout_overlay == null:
		_layout_overlay = LAYOUT_OVERLAY_SCENE.instantiate()
		$UI.add_child(_layout_overlay)
		_layout_overlay.layout_saved.connect(_on_layout_saved)
		_layout_overlay.closed.connect(_on_layout_overlay_closed)
	_layout_overlay.setup(_layout_overlay_data())
	_layout_overlay.open_overlay()


func _on_layout_saved(objects: Array) -> void:
	_layout_objects = []
	for obj in objects:
		_layout_objects.append({"type": str(obj["type"]), "pos": obj["pos"]})
	_save_layout_objects(_layout_objects)
	_blocked_cells = _build_blocked_cells()
	character.set_blocked_cells(_blocked_cells)
	status_label.text = "房间布置已保存"
	queue_redraw()


func _on_layout_overlay_closed() -> void:
	status_label.text = "房间布置已关闭"


func _get_furniture_at(cell: Vector2i) -> Dictionary:
	for furniture in _furniture_list:
		if cell in furniture["cells"]:
			return furniture
	return {}


func _is_adjacent_to_furniture(current_cell: Vector2i, cells: Array) -> bool:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for furniture_cell in cells:
		for dir in dirs:
			if current_cell == furniture_cell + dir:
				return true
	return false


func _find_nearest_free_cell_near_furniture(cells: Array) -> Vector2i:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	var candidates: Array = []
	for furniture_cell in cells:
		for dir in dirs:
			var neighbor: Vector2i = furniture_cell + dir
			if _inside_grid(neighbor) and not _blocked_cells.has(neighbor):
				candidates.append(neighbor)

	if candidates.is_empty():
		return _find_global_nearest_free_cell()

	var best: Vector2i = candidates[0]
	var best_dist := _manhattan(character.current_cell, best)
	for candidate in candidates:
		var candidate_cell: Vector2i = candidate
		var dist := _manhattan(character.current_cell, candidate_cell)
		if dist < best_dist:
			best = candidate_cell
			best_dist = dist
	return best


func _find_global_nearest_free_cell() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 1 << 30
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var candidate := Vector2i(x, y)
			if _blocked_cells.has(candidate):
				continue
			var dist := _manhattan(character.current_cell, candidate)
			if dist < best_dist:
				best = candidate
				best_dist = dist
	return best


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _draw() -> void:
	var room_size := Vector2(GRID_SIZE.x, GRID_SIZE.y) * CELL_SIZE

	_draw_wall(room_size)
	_draw_floor(room_size)
	_draw_furniture()
	_draw_target()
	_draw_path()


func _draw_wall(room_size: Vector2) -> void:
	var wall_rect := Rect2(
		GRID_ORIGIN + Vector2(0, -WALL_HEIGHT),
		Vector2(room_size.x, WALL_HEIGHT)
	)

	# 温馨米色墙面
	draw_rect(wall_rect, Color(0.93, 0.82, 0.68))

	# 墙纸竖条纹
	var stripe_color := Color(0.97, 0.89, 0.78)
	for x in range(GRID_SIZE.x + 1):
		var x_pos := GRID_ORIGIN.x + x * CELL_SIZE
		draw_line(
			Vector2(x_pos, wall_rect.position.y),
			Vector2(x_pos, wall_rect.position.y + wall_rect.size.y),
			stripe_color,
			1.0
		)

	# 踢脚线：向下压几像素，和地板无缝衔接
	draw_rect(
		Rect2(GRID_ORIGIN + Vector2(0, -6), Vector2(room_size.x, 8)),
		Color(0.55, 0.36, 0.25)
	)
	# 墙与地板接缝线
	draw_line(
		GRID_ORIGIN,
		GRID_ORIGIN + Vector2(room_size.x, 0),
		Color(0.42, 0.27, 0.18),
		2.0
	)


func _draw_floor(room_size: Vector2) -> void:
	# 暖色木地板
	draw_rect(Rect2(GRID_ORIGIN, room_size), Color(0.72, 0.53, 0.36))

	# 木板棋盘明暗
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			if (x + y) % 2 == 0:
				var cell_rect := Rect2(
					GRID_ORIGIN + Vector2(x, y) * CELL_SIZE,
					Vector2(CELL_SIZE, CELL_SIZE)
				)
				draw_rect(cell_rect, Color(0.65, 0.46, 0.30))

	# 木地板拼缝
	var line_color := Color(0.45, 0.30, 0.20)
	for x in range(GRID_SIZE.x + 1):
		var x_pos := GRID_ORIGIN.x + x * CELL_SIZE
		draw_line(
			Vector2(x_pos, GRID_ORIGIN.y),
			Vector2(x_pos, GRID_ORIGIN.y + room_size.y),
			line_color,
			1.0
		)
	for y in range(GRID_SIZE.y + 1):
		var y_pos := GRID_ORIGIN.y + y * CELL_SIZE
		draw_line(
			Vector2(GRID_ORIGIN.x, y_pos),
			Vector2(GRID_ORIGIN.x + room_size.x, y_pos),
			line_color,
			1.0
		)

	# 地板外框
	draw_rect(
		Rect2(GRID_ORIGIN - Vector2(2, 2), room_size + Vector2(4, 4)),
		Color(0.35, 0.22, 0.15),
		false,
		2.0
	)


func _draw_furniture() -> void:
	_draw_bed()
	_draw_desk()
	_draw_bookshelf()
	_draw_chair()
	_draw_tv()
	_draw_sofa()
	_draw_window()
	_draw_rug()
	_draw_lamp()
	_draw_plant()
	_draw_layout_desk()


func _draw_bed() -> void:
	var bed := _cell_rect(_furniture_pos("bed"), Vector2i(2, 2))
	draw_rect(bed, Color(0.62, 0.42, 0.28))
	# 床头
	draw_rect(Rect2(bed.position, Vector2(bed.size.x, 3)), Color(0.48, 0.31, 0.20))
	# 枕头
	draw_rect(
		Rect2(bed.position + Vector2(3, 3), Vector2(9, 5)),
		Color(0.98, 0.91, 0.80)
	)
	# 被子
	draw_rect(
		Rect2(bed.position + Vector2(2, 9), Vector2(bed.size.x - 4, bed.size.y - 11)),
		Color(0.85, 0.45, 0.42)
	)


func _draw_desk() -> void:
	var desk := _cell_rect(_furniture_pos("desk"), Vector2i(2, 1))

	# 外框
	draw_rect(
		Rect2(desk.position + Vector2(1, 1), Vector2(30, 14)),
		Color(0.30, 0.20, 0.14),
		false,
		1.0
	)

	# 显示器外框
	draw_rect(
		Rect2(desk.position + Vector2(9, 0), Vector2(14, 9)),
		Color(0.22, 0.22, 0.30)
	)
	# 屏幕
	draw_rect(
		Rect2(desk.position + Vector2(11, 1), Vector2(10, 7)),
		Color(0.55, 0.85, 0.95)
	)
	# 屏幕高光
	draw_rect(
		Rect2(desk.position + Vector2(12, 2), Vector2(5, 2)),
		Color(0.75, 0.95, 1.0)
	)
	# 显示器底座
	draw_rect(
		Rect2(desk.position + Vector2(14, 9), Vector2(4, 2)),
		Color(0.20, 0.20, 0.28)
	)
	draw_rect(
		Rect2(desk.position + Vector2(12, 11), Vector2(8, 2)),
		Color(0.20, 0.20, 0.28)
	)
	# 桌面
	draw_rect(
		Rect2(desk.position + Vector2(1, 11), Vector2(30, 4)),
		Color(0.62, 0.43, 0.27)
	)
	# 桌沿阴影
	draw_rect(
		Rect2(desk.position + Vector2(1, 14), Vector2(30, 1)),
		Color(0.42, 0.28, 0.18)
	)
	# 键盘
	draw_rect(
		Rect2(desk.position + Vector2(20, 12), Vector2(8, 2)),
		Color(0.32, 0.30, 0.40)
	)


func _draw_bookshelf() -> void:
	var shelf := _cell_rect(_furniture_pos("shelf"), Vector2i(2, 1))
	# 外框
	draw_rect(shelf, Color(0.45, 0.30, 0.20))
	# 内侧
	draw_rect(
		Rect2(shelf.position + Vector2(2, 2), Vector2(28, 12)),
		Color(0.30, 0.20, 0.14)
	)
	# 中间隔板
	draw_line(
		shelf.position + Vector2(2, 8),
		shelf.position + Vector2(30, 8),
		Color(0.45, 0.30, 0.20),
		2.0
	)
	# 上层书
	draw_rect(Rect2(shelf.position + Vector2(4, 3), Vector2(3, 4)), Color(0.80, 0.45, 0.40))
	draw_rect(Rect2(shelf.position + Vector2(8, 3), Vector2(3, 4)), Color(0.45, 0.60, 0.80))
	draw_rect(Rect2(shelf.position + Vector2(12, 3), Vector2(3, 4)), Color(0.70, 0.65, 0.45))
	draw_rect(Rect2(shelf.position + Vector2(16, 3), Vector2(3, 4)), Color(0.50, 0.70, 0.55))
	# 下层书
	draw_rect(Rect2(shelf.position + Vector2(5, 10), Vector2(3, 4)), Color(0.75, 0.55, 0.35))
	draw_rect(Rect2(shelf.position + Vector2(10, 10), Vector2(3, 4)), Color(0.60, 0.50, 0.70))
	draw_rect(Rect2(shelf.position + Vector2(15, 10), Vector2(3, 4)), Color(0.55, 0.65, 0.50))
	draw_rect(Rect2(shelf.position + Vector2(20, 10), Vector2(3, 4)), Color(0.80, 0.60, 0.55))


func _draw_chair() -> void:
	var chair := _cell_rect(_furniture_pos("chair"), Vector2i(1, 1))
	# 椅背
	draw_rect(
		Rect2(chair.position + Vector2(4, 1), Vector2(8, 4)),
		Color(0.55, 0.38, 0.25)
	)
	# 椅座
	draw_rect(
		Rect2(chair.position + Vector2(3, 5), Vector2(10, 3)),
		Color(0.62, 0.43, 0.27)
	)
	# 椅腿
	draw_rect(
		Rect2(chair.position + Vector2(4, 8), Vector2(2, 6)),
		Color(0.42, 0.28, 0.18)
	)
	draw_rect(
		Rect2(chair.position + Vector2(10, 8), Vector2(2, 6)),
		Color(0.42, 0.28, 0.18)
	)


func _draw_tv() -> void:
	var tv := _cell_rect(_furniture_pos("tv"), Vector2i(2, 1))
	# 电视外框
	draw_rect(
		Rect2(tv.position + Vector2(8, 0), Vector2(16, 9)),
		Color(0.22, 0.22, 0.30)
	)
	# 屏幕
	draw_rect(
		Rect2(tv.position + Vector2(10, 1), Vector2(12, 7)),
		Color(0.50, 0.75, 0.90)
	)
	# 屏幕高光
	draw_rect(
		Rect2(tv.position + Vector2(11, 2), Vector2(5, 2)),
		Color(0.75, 0.95, 1.0)
	)
	# 电视底座
	draw_rect(
		Rect2(tv.position + Vector2(14, 9), Vector2(4, 2)),
		Color(0.20, 0.20, 0.28)
	)
	# 电视柜
	draw_rect(
		Rect2(tv.position + Vector2(2, 11), Vector2(28, 4)),
		Color(0.62, 0.43, 0.27)
	)
	draw_rect(
		Rect2(tv.position + Vector2(2, 14), Vector2(28, 1)),
		Color(0.42, 0.28, 0.18)
	)


func _draw_sofa() -> void:
	var sofa := _cell_rect(_furniture_pos("sofa"), Vector2i(2, 1))
	# 沙发靠背
	draw_rect(
		Rect2(sofa.position + Vector2(2, 2), Vector2(28, 5)),
		Color(0.78, 0.48, 0.45)
	)
	# 座垫
	draw_rect(
		Rect2(sofa.position + Vector2(4, 7), Vector2(24, 5)),
		Color(0.85, 0.58, 0.52)
	)
	# 扶手
	draw_rect(
		Rect2(sofa.position + Vector2(1, 5), Vector2(3, 8)),
		Color(0.68, 0.38, 0.35)
	)
	draw_rect(
		Rect2(sofa.position + Vector2(28, 5), Vector2(3, 8)),
		Color(0.68, 0.38, 0.35)
	)
	# 沙发腿
	draw_rect(
		Rect2(sofa.position + Vector2(4, 13), Vector2(2, 2)),
		Color(0.42, 0.28, 0.18)
	)
	draw_rect(
		Rect2(sofa.position + Vector2(26, 13), Vector2(2, 2)),
		Color(0.42, 0.28, 0.18)
	)


func _draw_plant() -> void:
	var plant := _cell_rect(_furniture_pos("plant"), Vector2i(1, 1))
	# 叶子
	draw_rect(
		Rect2(plant.position + Vector2(6, 2), Vector2(4, 6)),
		Color(0.45, 0.65, 0.40)
	)
	draw_rect(
		Rect2(plant.position + Vector2(3, 4), Vector2(3, 5)),
		Color(0.38, 0.58, 0.36)
	)
	draw_rect(
		Rect2(plant.position + Vector2(10, 4), Vector2(3, 5)),
		Color(0.38, 0.58, 0.36)
	)
	# 花盆
	draw_rect(
		Rect2(plant.position + Vector2(5, 9), Vector2(6, 5)),
		Color(0.72, 0.44, 0.32)
	)
	draw_rect(
		Rect2(plant.position + Vector2(4, 10), Vector2(8, 2)),
		Color(0.60, 0.35, 0.26)
	)


func _draw_layout_desk() -> void:
	var desk := _cell_rect(_furniture_pos("layout"), Vector2i(1, 1))
	# 台面
	draw_rect(
		Rect2(desk.position + Vector2(1, 6), Vector2(14, 8)),
		Color(0.66, 0.46, 0.28)
	)
	# 图纸
	draw_rect(
		Rect2(desk.position + Vector2(3, 3), Vector2(10, 8)),
		Color(0.75, 0.85, 0.95)
	)
	# 图纸网格
	draw_line(
		desk.position + Vector2(3, 7),
		desk.position + Vector2(13, 7),
		Color(0.55, 0.65, 0.80),
		1.0
	)
	draw_line(
		desk.position + Vector2(8, 3),
		desk.position + Vector2(8, 11),
		Color(0.55, 0.65, 0.80),
		1.0
	)
	# 铅笔
	draw_rect(
		Rect2(desk.position + Vector2(1, 2), Vector2(2, 9)),
		Color(0.90, 0.75, 0.35)
	)
	draw_rect(
		Rect2(desk.position + Vector2(1, 2), Vector2(2, 2)),
		Color(0.95, 0.80, 0.90)
	)


func _draw_window() -> void:
	var frame := Rect2(
		GRID_ORIGIN + Vector2(2 * CELL_SIZE, -WALL_HEIGHT + 8),
		Vector2(48, 30)
	)
	draw_rect(frame, Color(0.95, 0.90, 0.80))
	draw_rect(
		Rect2(frame.position + Vector2(3, 3), frame.size - Vector2(6, 6)),
		Color(0.55, 0.75, 0.90)
	)
	# 窗框十字
	draw_line(
		frame.position + Vector2(frame.size.x / 2.0, 3),
		frame.position + Vector2(frame.size.x / 2.0, frame.size.y - 3),
		Color(0.95, 0.90, 0.80),
		2.0
	)
	draw_line(
		frame.position + Vector2(3, frame.size.y / 2.0),
		frame.position + Vector2(frame.size.x - 3, frame.size.y / 2.0),
		Color(0.95, 0.90, 0.80),
		2.0
	)


func _draw_rug() -> void:
	var rug := _cell_rect(Vector2i(0, 6), Vector2i(2, 2))
	draw_rect(rug, Color(0.82, 0.55, 0.42))
	draw_rect(
		Rect2(rug.position + Vector2(3, 3), rug.size - Vector2(6, 6)),
		Color(0.90, 0.68, 0.54),
		false,
		1.0
	)


func _draw_lamp() -> void:
	var lamp := _cell_rect(_furniture_pos("lamp"), Vector2i(1, 1))
	# 灯罩
	draw_rect(
		Rect2(lamp.position + Vector2(5, 2), Vector2(6, 4)),
		Color(1.0, 0.87, 0.58)
	)
	# 灯杆
	draw_rect(
		Rect2(lamp.position + Vector2(7, 6), Vector2(2, 7)),
		Color(0.45, 0.35, 0.30)
	)
	# 底座
	draw_rect(
		Rect2(lamp.position + Vector2(4, 13), Vector2(8, 2)),
		Color(0.38, 0.30, 0.26)
	)


func _draw_target() -> void:
	if _target_cell.x < 0:
		return
	var center := _cell_center(_target_cell)
	var color := Color(1.0, 0.78, 0.30, 0.85)
	draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), color, 2.0)
	draw_line(center + Vector2(0, -5), center + Vector2(0, 5), color, 2.0)
	draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color, false, 1.0)


func _draw_path() -> void:
	var path: Array = character.get_current_path()
	if path.is_empty():
		return
	var points: Array = [character.position]
	for cell in path:
		points.append(_cell_center(cell))
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(1.0, 0.78, 0.30, 0.65), 1.0)
		draw_circle(points[i + 1], 2.0, Color(1.0, 0.78, 0.30, 0.85))


func _cell_rect(cell: Vector2i, size: Vector2i) -> Rect2:
	return Rect2(
		GRID_ORIGIN + Vector2(cell.x, cell.y) * CELL_SIZE,
		Vector2(size.x, size.y) * CELL_SIZE
	)


func _cell_center(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell.x, cell.y) * CELL_SIZE + HALF_CELL


func _pixel_to_cell(pos: Vector2) -> Vector2i:
	var local := (pos - GRID_ORIGIN) / CELL_SIZE
	return Vector2i(floori(local.x), floori(local.y))


func _inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


func _on_state_changed(state_name: String) -> void:
	if state_name == "walk":
		status_label.text = "角色正在走路…"
	else:
		status_label.text = "角色已到达"
