extends Control
## P4：贪吃蛇（与 AI 对战）。玩家蛇（蓝）与 AI 蛇（红）同场抢一个食物，
## 吃到食物 +1 分并生长；先到 WIN_SCORE（8 分）者获胜；
## 撞墙/撞自己/撞对方即失败（双方同时撞 = 平局）。
## 方向键 / WASD 控制；胜负沿用通用规则：胜 +3 / 平 +1 / 负 0；记录日常事件 snake。

signal back_requested
signal game_finished(result: String)
signal game_restarted
signal game_exited

const CELL := 12.0
const GRID_W := 24
const GRID_H := 15
const BOARD_ORIGIN := Vector2(14, 70)
const WIN_SCORE := 8
const TICK_TIME := 0.16

const DIR_UP := Vector2i(0, -1)
const DIR_DOWN := Vector2i(0, 1)
const DIR_LEFT := Vector2i(-1, 0)
const DIR_RIGHT := Vector2i(1, 0)

var _player: Dictionary = {}
var _ai: Dictionary = {}
var _food := Vector2i(0, 0)
var _game_over := false
var _tick_accum := 0.0
var _ai_name := "梅尔"

@onready var status_label: Label = $StatusLabel
@onready var score_label: Label = $ScoreLabel
@onready var restart_button: Button = $RestartButton
@onready var back_button: Button = $BackButton
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel
@onready var restart_result_button: Button = $ResultPanel/RestartResultButton
@onready var exit_result_button: Button = $ResultPanel/ExitResultButton


func _ready() -> void:
	_ai_name = CharacterCatalog.get_display_name(GameManager.get_current_char_id())
	restart_button.pressed.connect(_on_restart_pressed)
	back_button.pressed.connect(_on_back_pressed)
	restart_result_button.pressed.connect(_on_restart_result_pressed)
	exit_result_button.pressed.connect(_on_exit_result_pressed)
	result_panel.visible = false
	_reset_game()


func _process(delta: float) -> void:
	if _game_over:
		return
	_tick_accum += delta
	while _tick_accum >= TICK_TIME and not _game_over:
		_tick_accum -= TICK_TIME
		_tick()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var dir := Vector2i.ZERO
	match (event as InputEventKey).keycode:
		KEY_UP, KEY_W:
			dir = DIR_UP
		KEY_DOWN, KEY_S:
			dir = DIR_DOWN
		KEY_LEFT, KEY_A:
			dir = DIR_LEFT
		KEY_RIGHT, KEY_D:
			dir = DIR_RIGHT
	if dir != Vector2i.ZERO:
		_set_player_dir(dir)


func _set_player_dir(dir: Vector2i) -> void:
	if _game_over:
		return
	var cur: Vector2i = _player["dir"]
	if dir == -cur:
		return
	_player["dir"] = dir


## ---------------- 初始化 ----------------


func _reset_game() -> void:
	var mid := GRID_H / 2
	_player = {
		"body": [Vector2i(5, mid), Vector2i(4, mid), Vector2i(3, mid)],
		"dir": DIR_RIGHT,
		"score": 0,
	}
	_ai = {
		"body": [Vector2i(18, mid), Vector2i(19, mid), Vector2i(20, mid)],
		"dir": DIR_LEFT,
		"score": 0,
	}
	_game_over = false
	_tick_accum = 0.0
	result_panel.visible = false
	_spawn_food()
	_update_labels()
	queue_redraw()


func _spawn_food() -> void:
	var occupied := {}
	for c in _player["body"]:
		occupied[c] = true
	for c in _ai["body"]:
		occupied[c] = true
	for _i in range(300):
		var cell := Vector2i(randi_range(0, GRID_W - 1), randi_range(0, GRID_H - 1))
		if not occupied.has(cell):
			_food = cell
			return


## ---------------- 主循环 ----------------


func _tick() -> void:
	if _game_over:
		return
	var p_body: Array = _player["body"]
	var a_body: Array = _ai["body"]

	# AI 决策：每次 tick 选择一个安全方向（趋向食物）
	_ai["dir"] = _ai_choose_dir()

	var p_head: Vector2i = p_body[0] + _player["dir"]
	var a_head: Vector2i = a_body[0] + _ai["dir"]
	var p_eat := p_head == _food
	var a_eat := a_head == _food
	var p_dead := false
	var a_dead := false

	# 撞墙
	if not _inside(p_head):
		p_dead = true
	if not _inside(a_head):
		a_dead = true

	# 撞自己（尾巴会移动，除非本 tick 吃到食物）
	var p_self: Array = p_body if p_eat else p_body.slice(0, p_body.size() - 1)
	var a_self: Array = a_body if a_eat else a_body.slice(0, a_body.size() - 1)
	if not p_dead and p_head in p_self:
		p_dead = true
	if not a_dead and a_head in a_self:
		a_dead = true

	# 撞对方（对方尾巴同样移动）
	var p_opp: Array = a_body if a_eat else a_body.slice(0, a_body.size() - 1)
	var a_opp: Array = p_body if p_eat else p_body.slice(0, p_body.size() - 1)
	if not p_dead and p_head in p_opp:
		p_dead = true
	if not a_dead and a_head in a_opp:
		a_dead = true

	# 头对头 = 同归于尽
	if p_head == a_head:
		p_dead = true
		a_dead = true

	if p_dead and a_dead:
		_finish_game("双方相撞，平局", "draw")
		return
	if p_dead:
		_finish_game("%s 赢了（你的蛇撞上了）" % _ai_name, "lose")
		return
	if a_dead:
		_finish_game("你赢了！%s 的蛇撞上了" % _ai_name, "win")
		return

	# 应用移动
	var p_new: Array = [p_head]
	p_new.append_array(p_body)
	if not p_eat:
		p_new.pop_back()
	_player["body"] = p_new
	if p_eat:
		_player["score"] += 1
		_spawn_food()

	var a_new: Array = [a_head]
	a_new.append_array(a_body)
	if not a_eat:
		a_new.pop_back()
	_ai["body"] = a_new
	if a_eat:
		_ai["score"] += 1
		_spawn_food()

	_update_labels()
	queue_redraw()

	if int(_player["score"]) >= WIN_SCORE:
		_finish_game("你吃到了 %d 个食物，获胜！" % WIN_SCORE, "win")
		return
	if int(_ai["score"]) >= WIN_SCORE:
		_finish_game("%s 先吃到了 %d 个食物" % [_ai_name, WIN_SCORE], "lose")


func _ai_choose_dir() -> Vector2i:
	var cur: Vector2i = _ai["dir"]
	var head: Vector2i = _ai["body"][0]
	var options: Array = []
	for dir in [DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT]:
		if dir == -cur:
			continue
		var next: Vector2i = head + dir
		if _safe_for_ai(next):
			options.append(dir)
	if options.is_empty():
		return cur

	var best: Array = []
	var best_dist := 1 << 30
	for dir in options:
		var d := _ai_distance(dir)
		if d < best_dist:
			best_dist = d
			best = [dir]
		elif d == best_dist:
			best.append(dir)
	return best[randi_range(0, best.size() - 1)]


func _ai_distance(dir: Vector2i) -> int:
	var next: Vector2i = _ai["body"][0] + dir
	return absi(next.x - _food.x) + absi(next.y - _food.y)


func _safe_for_ai(next: Vector2i) -> bool:
	if not _inside(next):
		return false
	var a_body: Array = _ai["body"]
	if next in a_body.slice(0, a_body.size() - 1):
		return false
	var p_body: Array = _player["body"]
	if next in p_body.slice(0, p_body.size() - 1):
		return false
	return true


## ---------------- 绘制 ----------------


func _draw() -> void:
	var board_rect := Rect2(BOARD_ORIGIN, Vector2(GRID_W, GRID_H) * CELL)
	draw_rect(board_rect, Color(0.12, 0.11, 0.14))
	var line_color := Color(0.20, 0.18, 0.22)
	for x in range(GRID_W + 1):
		var x_pos := BOARD_ORIGIN.x + x * CELL
		draw_line(Vector2(x_pos, BOARD_ORIGIN.y), Vector2(x_pos, BOARD_ORIGIN.y + GRID_H * CELL), line_color, 1.0)
	for y in range(GRID_H + 1):
		var y_pos := BOARD_ORIGIN.y + y * CELL
		draw_line(Vector2(BOARD_ORIGIN.x, y_pos), Vector2(BOARD_ORIGIN.x + GRID_W * CELL, y_pos), line_color, 1.0)

	# 食物
	var fc := _cell_center(_food)
	draw_rect(Rect2(fc - Vector2(4, 4), Vector2(8, 8)), Color(0.92, 0.40, 0.38))
	draw_rect(Rect2(fc - Vector2(2, 2), Vector2(3, 3)), Color(0.98, 0.85, 0.70))

	# 玩家蛇（蓝）
	for i in range(_player["body"].size()):
		var cell: Vector2i = _player["body"][i]
		var color := Color(0.55, 0.88, 1.0) if i == 0 else Color(0.35, 0.62, 0.92)
		draw_rect(_cell_rect(cell), color)

	# AI 蛇（红）
	for i in range(_ai["body"].size()):
		var cell: Vector2i = _ai["body"][i]
		var color := Color(1.0, 0.72, 0.45) if i == 0 else Color(0.90, 0.40, 0.40)
		draw_rect(_cell_rect(cell), color)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		BOARD_ORIGIN + Vector2(cell.x, cell.y) * CELL + Vector2(1, 1),
		Vector2(CELL - 2, CELL - 2)
	)


func _cell_center(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(cell.x, cell.y) * CELL + Vector2(CELL / 2.0, CELL / 2.0)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_W and cell.y < GRID_H


## ---------------- 结算 / 结束 ----------------


func _finish_game(message: String, result: String) -> void:
	_game_over = true
	status_label.text = message
	result_label.text = message
	result_panel.visible = true
	queue_redraw()
	game_finished.emit(result)
	match result:
		"win":
			_on_game_won()
		"lose":
			_on_game_lost()
		"draw":
			_on_draw()


func _on_game_won() -> void:
	var char_id := GameManager.get_current_char_id()
	var delta := GameManager.on_game_finished(char_id, "win", "贪吃蛇")
	MemoryManager.record_daily_event(char_id, "snake", "win")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[Snake] 胜利，好感度 +%d" % delta)


func _on_game_lost() -> void:
	var char_id := GameManager.get_current_char_id()
	GameManager.on_game_finished(char_id, "lose", "贪吃蛇")
	MemoryManager.record_daily_event(char_id, "snake", "lose")
	print("[Snake] 失败接口预留")


func _on_draw() -> void:
	var char_id := GameManager.get_current_char_id()
	var delta := GameManager.on_game_finished(char_id, "draw", "贪吃蛇")
	MemoryManager.record_daily_event(char_id, "snake", "draw")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[Snake] 平局，好感度 +%d" % delta)


func _update_labels() -> void:
	score_label.text = "你 %d/%d　·　%s %d/%d　（先吃满 %d 胜）" % [
		int(_player["score"]), WIN_SCORE,
		_ai_name, int(_ai["score"]), WIN_SCORE,
		WIN_SCORE,
	]


## ---------------- 按钮 ----------------


func _on_restart_pressed() -> void:
	_reset_game()
	game_restarted.emit()


func _on_restart_result_pressed() -> void:
	_on_restart_pressed()


func _on_back_pressed() -> void:
	game_exited.emit()
	back_requested.emit()


func _on_exit_result_pressed() -> void:
	game_exited.emit()
	back_requested.emit()
