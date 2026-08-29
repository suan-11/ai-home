extends Control
## 房间布置网格：长按家具 0.4s 拾起 → 移动鼠标 → 点击放下。
## 不直接写盘；最终 objects 由浮层交给 GameMain 保存到 user://room_layout.json。

signal note_changed(text: String)

const GRID_SIZE := Vector2i(16, 12)
const CELL := 17.0
const LONG_PRESS := 0.4

var _objects: Array = []
var _held := -1
var _pressing := false
var _press_index := -1
var _press_time := 0.0
var _mouse_cell := Vector2i(-1, -1)
var _note := ""


func setup(objects: Array) -> void:
	_objects = []
	for obj in objects:
		_objects.append(obj.duplicate(true))
	_held = -1
	_pressing = false
	_press_index = -1
	_press_time = 0.0
	_mouse_cell = _pixel_to_cell(get_local_mouse_position())
	queue_redraw()


func is_holding() -> bool:
	return _held >= 0


func get_layout_objects() -> Array:
	return _objects


func _process(delta: float) -> void:
	if _pressing and _held < 0:
		_press_time += delta
		if _press_time >= LONG_PRESS:
			_held = _press_index
			_pressing = false
			_note = "已拾起「%s」，移动到目标格后点击放下" % str(_objects[_held]["name"])
			note_changed.emit(_note)
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_cell = _pixel_to_cell(event.position)
		if _held >= 0:
			queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_left_pressed(event.position)
		else:
			_on_left_released()


func _on_left_pressed(pos: Vector2) -> void:
	var cell := _pixel_to_cell(pos)
	if _held >= 0:
		_try_place(cell)
		return
	var index := _furniture_at(cell)
	if index >= 0:
		_pressing = true
		_press_index = index
		_press_time = 0.0


func _on_left_released() -> void:
	if _pressing and _held < 0:
		_pressing = false
		if _press_time < LONG_PRESS:
			_note = "长按「%s」0.4 秒才能拾起喵" % str(_objects[_press_index]["name"])
			note_changed.emit(_note)


func _try_place(cell: Vector2i) -> void:
	var obj: Dictionary = _objects[_held]
	var size: Vector2i = obj["size"]
	if not _can_place(cell, size):
		_note = "这里放不下（出界或有别的家具）"
		note_changed.emit(_note)
		return
	obj["pos"] = cell
	_held = -1
	_note = "已放下「%s」" % str(obj["name"])
	note_changed.emit(_note)
	queue_redraw()


func _can_place(cell: Vector2i, size: Vector2i) -> bool:
	for y in range(size.y):
		for x in range(size.x):
			var c := cell + Vector2i(x, y)
			if c.x < 0 or c.y < 0 or c.x >= GRID_SIZE.x or c.y >= GRID_SIZE.y:
				return false
			if _furniture_at(c) >= 0:
				return false
	return true


func _furniture_at(cell: Vector2i) -> int:
	for i in range(_objects.size()):
		if i == _held:
			continue
		var obj: Dictionary = _objects[i]
		var pos: Vector2i = obj["pos"]
		var size: Vector2i = obj["size"]
		if (
			cell.x >= pos.x
			and cell.x < pos.x + size.x
			and cell.y >= pos.y
			and cell.y < pos.y + size.y
		):
			return i
	return -1


func _pixel_to_cell(pos: Vector2) -> Vector2i:
	var local := Vector2(pos.x / CELL, pos.y / CELL)
	var cell := Vector2i(floori(local.x), floori(local.y))
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return Vector2i(-1, -1)
	return cell


func _draw() -> void:
	var grid_px := Vector2(GRID_SIZE) * CELL
	# 地板
	draw_rect(Rect2(Vector2.ZERO, grid_px), Color(0.72, 0.53, 0.36))
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			if (x + y) % 2 == 0:
				draw_rect(
					Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)),
					Color(0.65, 0.46, 0.30)
				)
	# 网格线
	var line_color := Color(0.45, 0.30, 0.20, 0.8)
	for x in range(GRID_SIZE.x + 1):
		draw_line(
			Vector2(x * CELL, 0),
			Vector2(x * CELL, grid_px.y),
			line_color,
			1.0
		)
	for y in range(GRID_SIZE.y + 1):
		draw_line(
			Vector2(0, y * CELL),
			Vector2(grid_px.x, y * CELL),
			line_color,
			1.0
		)
	# 家具块
	for i in range(_objects.size()):
		if i == _held:
			continue
		_draw_furniture_block(_objects[i], 1.0, true)
	# 抓取中的鬼影
	if _held >= 0 and _mouse_cell.x >= 0:
		var ghost: Dictionary = _objects[_held].duplicate(true)
		ghost["pos"] = _mouse_cell
		_draw_furniture_block(ghost, 0.55, _can_place(_mouse_cell, _objects[_held]["size"]))


func _draw_furniture_block(obj: Dictionary, alpha: float, valid: bool) -> void:
	var pos: Vector2i = obj["pos"]
	var size: Vector2i = obj["size"]
	var rect := Rect2(Vector2(pos) * CELL, Vector2(size) * CELL).grow(-1.5)
	var color: Color = obj["color"]
	color.a = alpha
	draw_rect(rect, color)
	var border := Color(0.25, 0.16, 0.10, alpha)
	if not valid:
		border = Color(0.85, 0.30, 0.30, alpha)
	draw_rect(rect, border, false, 1.5)
	var text := str(obj["name"]).substr(0, 1)
	if size.x >= 2:
		text = str(obj["name"]).substr(0, 2)
	var font := ThemeDB.fallback_font
	var text_pos := Vector2(rect.position.x + 3, rect.position.y + rect.size.y / 2.0 + 4)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, alpha))
