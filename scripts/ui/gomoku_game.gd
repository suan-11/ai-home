extends Control
## 标准 15×15 五子棋屏幕（运行在电脑系统屏幕区域内）。
## 玩家执黑，AI 执白；AI 使用启发式评分选择位置。
## 预留游戏结束信号，方便后续接入奖励/好感度等系统。

signal back_requested
signal game_finished(result: String)
signal game_restarted
signal game_exited

const BOARD_SIZE := 15
const CELL_SIZE := 16.0
const PLAYER := 1
const AI := 2
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(1, -1),
]

var board: Array = []
var current_turn: int = PLAYER
var game_over := false
var _ai_thinking := false

@onready var status_label: Label = $StatusLabel
@onready var restart_button: Button = $RestartButton
@onready var back_button: Button = $BackButton
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel
@onready var restart_result_button: Button = $ResultPanel/RestartResultButton
@onready var exit_result_button: Button = $ResultPanel/ExitResultButton


func _ready() -> void:
	_reset_board()
	restart_button.pressed.connect(_on_restart_pressed)
	back_button.pressed.connect(_on_back_pressed)
	restart_result_button.pressed.connect(_on_restart_result_pressed)
	exit_result_button.pressed.connect(_on_exit_result_pressed)
	result_panel.visible = false


func _draw() -> void:
	# 应用窗口背景
	var app_rect := _app_rect()
	draw_rect(app_rect, Color(0.20, 0.16, 0.20, 0.98))
	# 标题栏条
	draw_rect(
		Rect2(app_rect.position, Vector2(app_rect.size.x, 30)),
		Color(0.16, 0.13, 0.18)
	)

	# 标准 15 路棋盘
	var board_origin := _board_origin()
	var line_color := Color(0.72, 0.60, 0.45)
	var grid_size := (BOARD_SIZE - 1) * CELL_SIZE
	for i in range(BOARD_SIZE):
		var x := board_origin.x + i * CELL_SIZE
		var y := board_origin.y + i * CELL_SIZE
		draw_line(
			Vector2(x, board_origin.y),
			Vector2(x, board_origin.y + grid_size),
			line_color,
			1.0
		)
		draw_line(
			Vector2(board_origin.x, y),
			Vector2(board_origin.x + grid_size, y),
			line_color,
			1.0
		)

	# 标准星位
	for star in [Vector2i(3, 3), Vector2i(3, 11), Vector2i(11, 3), Vector2i(11, 11), Vector2i(7, 7)]:
		var center := _cell_center(star)
		draw_circle(center, 3.0, Color(0.72, 0.60, 0.45))

	# 棋子
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var value: int = board[row][col]
			if value == 0:
				continue
			var center := _cell_center(Vector2i(col, row))
			if value == PLAYER:
				draw_circle(center, 7.0, Color(0.12, 0.12, 0.14))
			else:
				draw_circle(center, 7.0, Color(0.95, 0.94, 0.92))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if game_over or _ai_thinking or current_turn != PLAYER:
				return
			var cell := _pixel_to_cell(event.position)
			if not _inside(cell):
				return
			if board[cell.y][cell.x] != 0:
				return

			_place_stone(cell, PLAYER)
			if _check_win(cell, PLAYER):
				_end_game("你赢了！", "win")
				return

			current_turn = AI
			_ai_thinking = true
			status_label.text = "AI 思考中…"
			_ai_move_async()


func _ai_move_async() -> void:
	await get_tree().create_timer(0.35).timeout
	if game_over:
		return

	var best := _find_best_ai_move()
	if best.x < 0:
		_end_game("平局", "draw")
		return

	_place_stone(best, AI)
	_ai_thinking = false
	if _check_win(best, AI):
		_end_game("AI 赢了", "lose")
		return

	current_turn = PLAYER
	status_label.text = "你的回合：点击交叉点落子"
	queue_redraw()


func _find_best_ai_move() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -1
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			if board[row][col] != 0:
				continue
			var cell := Vector2i(col, row)
			var attack := _score_cell(cell, AI)
			var defense := _score_cell(cell, PLAYER)
			var score := attack + int(defense * 0.9)
			if score > best_score:
				best_score = score
				best = cell
			elif score == best_score and _distance_to_center(cell) < _distance_to_center(best):
				best = cell
	return best


func _distance_to_center(cell: Vector2i) -> int:
	return absi(cell.x - 7) + absi(cell.y - 7)


func _score_cell(cell: Vector2i, player: int) -> int:
	var total := 0
	for dir in DIRS:
		total += _line_score(cell, dir, player)
	return total


func _line_score(cell: Vector2i, dir: Vector2i, player: int) -> int:
	var count := 1
	var open_ends := 0

	var cur := cell + dir
	while _inside(cur) and board[cur.y][cur.x] == player:
		count += 1
		cur += dir
	if _inside(cur) and board[cur.y][cur.x] == 0:
		open_ends += 1

	cur = cell - dir
	while _inside(cur) and board[cur.y][cur.x] == player:
		count += 1
		cur -= dir
	if _inside(cur) and board[cur.y][cur.x] == 0:
		open_ends += 1

	if count >= 5:
		return 100000
	if count == 4:
		return 10000 * (open_ends + 1)
	if count == 3:
		return 1000 * (open_ends + 1)
	if count == 2:
		return 100 * (open_ends + 1)
	return 10


func _check_win(cell: Vector2i, player: int) -> bool:
	for dir in DIRS:
		var count := 1
		count += _count_dir(cell, dir, player)
		count += _count_dir(cell, -dir, player)
		if count >= 5:
			return true
	return false


func _count_dir(start: Vector2i, dir: Vector2i, player: int) -> int:
	var count := 0
	var cur := start + dir
	while _inside(cur) and board[cur.y][cur.x] == player:
		count += 1
		cur += dir
	return count


func _place_stone(cell: Vector2i, player: int) -> void:
	board[cell.y][cell.x] = player
	queue_redraw()


func _end_game(message: String, result: String) -> void:
	game_over = true
	_ai_thinking = false
	status_label.text = message
	result_label.text = message
	result_panel.visible = true
	game_finished.emit(result)

	match result:
		"win":
			_on_game_won()
		"lose":
			_on_game_lost()
		"draw":
			_on_draw()


func _on_game_won() -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	var delta := GameManager.on_game_finished(char_id, "win")
	MemoryManager.record_daily_event(char_id, "gomoku", "win")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[Gomoku] 胜利，好感度 +%d" % delta)


func _on_game_lost() -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	GameManager.on_game_finished(char_id, "lose")
	MemoryManager.record_daily_event(char_id, "gomoku", "lose")
	print("[Gomoku] 失败接口预留")


func _on_draw() -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	var delta := GameManager.on_game_finished(char_id, "draw")
	MemoryManager.record_daily_event(char_id, "gomoku", "draw")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[Gomoku] 平局，好感度 +%d" % delta)


func _on_restart_pressed() -> void:
	_reset_board()
	result_panel.visible = false
	status_label.text = "你的回合：点击交叉点落子"
	queue_redraw()
	game_restarted.emit()


func _on_restart_result_pressed() -> void:
	_on_restart_pressed()


func _on_back_pressed() -> void:
	game_exited.emit()
	back_requested.emit()


func _on_exit_result_pressed() -> void:
	game_exited.emit()
	back_requested.emit()


func _reset_board() -> void:
	board.clear()
	for row in range(BOARD_SIZE):
		var line: Array = []
		for col in range(BOARD_SIZE):
			line.append(0)
		board.append(line)
	current_turn = PLAYER
	game_over = false
	_ai_thinking = false


func _pixel_to_cell(pos: Vector2) -> Vector2i:
	var local := (pos - _board_origin()) / CELL_SIZE
	return Vector2i(int(round(local.x)), int(round(local.y)))


func _cell_center(cell: Vector2i) -> Vector2:
	return _board_origin() + Vector2(cell.x, cell.y) * CELL_SIZE


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BOARD_SIZE and cell.y < BOARD_SIZE


func _board_origin() -> Vector2:
	return Vector2(14, 34)


func _app_rect() -> Rect2:
	return Rect2(Vector2(6, 6), size - Vector2(12, 12))
