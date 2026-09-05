extends Control
## P3：井字棋（与 AI 对战，玩家 X / AI O，胜利条件 3 连）。
## 运行在电脑系统屏幕区域内；胜负沿用通用规则（胜 +3 / 平 +1 / 负 0）。

signal back_requested
signal game_finished(result: String)
signal game_restarted
signal game_exited

const EMPTY := 0
const PLAYER := 1
const AI := 2
const BOARD_ORIGIN := Vector2(70, 54)
const CELL_SIZE := 60.0
const WINS := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

var board: Array = []
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
	var app_rect := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	draw_rect(app_rect, Color(0.16, 0.12, 0.10, 0.98))
	draw_rect(
		Rect2(app_rect.position, Vector2(app_rect.size.x, 30)),
		Color(0.42, 0.31, 0.23)
	)

	# 3×3 格子
	var line_color := Color(0.72, 0.60, 0.45)
	for i in range(1, 3):
		var x := BOARD_ORIGIN.x + i * CELL_SIZE
		draw_line(Vector2(x, BOARD_ORIGIN.y), Vector2(x, BOARD_ORIGIN.y + 3 * CELL_SIZE), line_color, 2.0)
		var y := BOARD_ORIGIN.y + i * CELL_SIZE
		draw_line(Vector2(BOARD_ORIGIN.x, y), Vector2(BOARD_ORIGIN.x + 3 * CELL_SIZE, y), line_color, 2.0)

	# 棋子
	for i in range(9):
		if board[i] == EMPTY:
			continue
		var center := _cell_center(i)
		if board[i] == PLAYER:
			var s := 14.0
			draw_line(center + Vector2(-s, -s), center + Vector2(s, s), Color(0.55, 0.85, 1.0), 3.0)
			draw_line(center + Vector2(-s, s), center + Vector2(s, -s), Color(0.55, 0.85, 1.0), 3.0)
		else:
			draw_arc(center, 16.0, 0.0, TAU, 32, Color(1.0, 0.5, 0.5), 3.0)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if game_over or _ai_thinking:
		return
	var index := _pixel_to_cell(event.position)
	if index < 0 or board[index] != EMPTY:
		return
	_place(index, PLAYER)
	if _is_win(PLAYER):
		_end_game("你赢了！", "win")
		return
	if _is_full():
		_end_game("平局", "draw")
		return
	_ai_thinking = true
	status_label.text = "AI 思考中…"
	_ai_move_async()


func _ai_move_async() -> void:
	await get_tree().create_timer(0.35).timeout
	if game_over:
		return
	var best := _find_ai_move()
	if best < 0:
		_end_game("平局", "draw")
		return
	_place(best, AI)
	_ai_thinking = false
	if _is_win(AI):
		_end_game("AI 赢了", "lose")
		return
	if _is_full():
		_end_game("平局", "draw")
		return
	status_label.text = "你的回合：点击空格落子"
	queue_redraw()


func _find_ai_move() -> int:
	# 1) 能赢就赢
	for i in range(9):
		if board[i] == EMPTY:
			board[i] = AI
			var win := _is_win(AI)
			board[i] = EMPTY
			if win:
				return i
	# 2) 堵玩家
	for i in range(9):
		if board[i] == EMPTY:
			board[i] = PLAYER
			var win := _is_win(PLAYER)
			board[i] = EMPTY
			if win:
				return i
	# 3) 中心
	if board[4] == EMPTY:
		return 4
	# 4) 随机角
	var corners: Array = [0, 2, 6, 8]
	var free: Array = []
	for c in corners:
		if board[c] == EMPTY:
			free.append(c)
	if not free.is_empty():
		return free[randi_range(0, free.size() - 1)]
	# 5) 任意
	for i in range(9):
		if board[i] == EMPTY:
			return i
	return -1


func _place(index: int, value: int) -> void:
	board[index] = value
	queue_redraw()


func _is_win(player: int) -> bool:
	for w in WINS:
		if board[w[0]] == player and board[w[1]] == player and board[w[2]] == player:
			return true
	return false


func _is_full() -> bool:
	for v in board:
		if v == EMPTY:
			return false
	return true


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
	var delta := GameManager.on_game_finished(char_id, "win", "井字棋")
	MemoryManager.record_daily_event(char_id, "tictactoe", "win")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[TicTacToe] 胜利，好感度 +%d" % delta)


func _on_game_lost() -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	GameManager.on_game_finished(char_id, "lose", "井字棋")
	MemoryManager.record_daily_event(char_id, "tictactoe", "lose")
	print("[TicTacToe] 失败接口预留")


func _on_draw() -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	var delta := GameManager.on_game_finished(char_id, "draw", "井字棋")
	MemoryManager.record_daily_event(char_id, "tictactoe", "draw")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[TicTacToe] 平局，好感度 +%d" % delta)


func _on_restart_pressed() -> void:
	_reset_board()
	result_panel.visible = false
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
	for i in range(9):
		board.append(EMPTY)
	game_over = false
	_ai_thinking = false
	status_label.text = "你的回合：点击空格落子"
	queue_redraw()


func _pixel_to_cell(pos: Vector2) -> int:
	var local := pos - BOARD_ORIGIN
	if local.x < 0.0 or local.y < 0.0:
		return -1
	var col := int(local.x / CELL_SIZE)
	var row := int(local.y / CELL_SIZE)
	if col > 2 or row > 2:
		return -1
	return row * 3 + col


func _cell_center(index: int) -> Vector2:
	var col := index % 3
	var row := index / 3
	return BOARD_ORIGIN + Vector2(col * CELL_SIZE + CELL_SIZE / 2.0, row * CELL_SIZE + CELL_SIZE / 2.0)
