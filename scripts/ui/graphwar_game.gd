extends Control
## P3：Graphwar 仿·函数对打（直接输入函数版）
## 玩家与 AI 各有一个出发点；输入关于 x 的函数 f(x)（x = 离开出发点的水平距离），
## 炮弹从自己的位置沿「y = 出发高度 + f(x)」飞行；命中对方位置 +1，先得 WIN_SCORE 分获胜。
## 运行在电脑系统屏幕区域内，胜负沿用通用规则（胜 +3 / 平 +1 / 负 0）。

signal back_requested
signal game_finished(result: String)
signal game_restarted
signal game_exited

const WIN_SCORE := 3
const HIT_RADIUS_PX := 7.0
const SHOT_DURATION := 0.9
const AI_HIT_CHANCE := 0.65
const AI_THINK_TIME := 0.6

const X_MIN := -10.0
const X_MAX := 10.0
const Y_MIN := -5.0
const Y_MAX := 5.0
const START_X_PLAYER := -8.0
const START_X_AI := 8.0
const MAX_TRAVEL := 24.0
const BOARD_RECT := Rect2(10, 36, 288, 222)

enum Phase { SELECT, PLAYER_FIRE, AI_THINK, AI_FIRE, GAME_OVER }

var _phase: int = Phase.SELECT
var _player_score := 0
var _ai_score := 0
var _player_y := 0.0
var _ai_y := 0.0
var _player_expr := ""
var _ai_expr := ""
var _player_path := PackedVector2Array()
var _ai_path := PackedVector2Array()
var _active_path := PackedVector2Array()
var _active_color := Color.WHITE
var _anim_progress := 0.0
var _ball_pos := Vector2.ZERO

# 表达式解析器状态
var _parse_failed := false
var _tokens: Array = []
var _token_i := 0

@onready var status_label: Label = $StatusLabel
@onready var score_label: Label = $ScoreLabel
@onready var formula_input: LineEdit = $Controls/FormulaInput
@onready var fire_button: Button = $Controls/FireButton
@onready var ai_status_label: Label = $Controls/AiStatusLabel
@onready var tutorial_button: Button = $Controls/TutorialButton
@onready var tutorial_panel: Panel = $TutorialPanel
@onready var tutorial_close_button: Button = $TutorialPanel/CloseButton
@onready var restart_button: Button = $Controls/RestartButton
@onready var back_button: Button = $Controls/BackButton
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel
@onready var restart_result_button: Button = $ResultPanel/RestartResultButton
@onready var exit_result_button: Button = $ResultPanel/ExitResultButton


func _ready() -> void:
	result_panel.visible = false
	tutorial_panel.visible = false
	formula_input.text_submitted.connect(_on_fire_pressed)
	fire_button.pressed.connect(_on_fire_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	tutorial_close_button.pressed.connect(_on_tutorial_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	back_button.pressed.connect(_on_back_pressed)
	restart_result_button.pressed.connect(_on_restart_result_pressed)
	exit_result_button.pressed.connect(_on_exit_result_pressed)
	_start_round()


func _draw() -> void:
	# 应用窗口背景 + 标题栏
	var app_rect := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	draw_rect(app_rect, Color(0.12, 0.15, 0.21))
	draw_rect(Rect2(Vector2(6, 6), Vector2(app_rect.size.x, 30)), Color(0.09, 0.11, 0.16))

	# 坐标平面
	draw_rect(BOARD_RECT, Color(0.16, 0.19, 0.27))
	draw_rect(BOARD_RECT, Color(0.30, 0.35, 0.45), false, 1.0)

	var grid_color := Color(0.35, 0.40, 0.50, 0.35)
	for x in range(int(X_MIN), int(X_MAX) + 1, 2):
		draw_line(_world_to_screen(Vector2(x, Y_MIN)), _world_to_screen(Vector2(x, Y_MAX)), grid_color, 1.0)
	for y in range(int(Y_MIN), int(Y_MAX) + 1, 1):
		draw_line(_world_to_screen(Vector2(X_MIN, y)), _world_to_screen(Vector2(X_MAX, y)), grid_color, 1.0)

	var axis_color := Color(0.50, 0.55, 0.65)
	draw_line(_world_to_screen(Vector2(X_MIN, 0)), _world_to_screen(Vector2(X_MAX, 0)), axis_color, 1.4)
	draw_line(_world_to_screen(Vector2(0, Y_MIN)), _world_to_screen(Vector2(0, Y_MAX)), axis_color, 1.4)

	# 出发点：玩家（左侧蓝菱形） vs AI（右侧红圆）
	_draw_player_start()
	_draw_ai_start()

	# 已发射轨迹（仅发射后显示，发射前不画辅助线）
	if _player_path.size() > 1:
		draw_polyline(_player_path, Color(0.55, 0.85, 1.0), 2.0)
	if _ai_path.size() > 1:
		draw_polyline(_ai_path, Color(1.0, 0.5, 0.5), 2.0)

	# 飞行中的小球
	if not _active_path.is_empty() and _anim_progress < 1.0:
		draw_circle(_ball_pos, 4.0, _active_color)
		draw_circle(_ball_pos, 7.0, Color(_active_color.r, _active_color.g, _active_color.b, 0.3))


func _draw_player_start() -> void:
	var center := _world_to_screen(Vector2(START_X_PLAYER, _player_y))
	var pts := PackedVector2Array([
		center + Vector2(0, -6), center + Vector2(5, 0),
		center + Vector2(0, 6), center + Vector2(-5, 0),
	])
	for i in range(4):
		draw_line(pts[i], pts[(i + 1) % 4], Color(0.45, 0.75, 1.0), 2.0)
	draw_circle(center, 2.0, Color(0.55, 0.85, 1.0))
	draw_string(ThemeDB.fallback_font, center + Vector2(-8, 18), "你", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.85, 1.0))


func _draw_ai_start() -> void:
	var center := _world_to_screen(Vector2(START_X_AI, _ai_y))
	draw_circle(center, 6.0, Color(1.0, 0.45, 0.45))
	draw_circle(center, 2.0, Color(1.0, 0.8, 0.8))
	draw_string(ThemeDB.fallback_font, center + Vector2(-4, 18), "AI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.7, 0.7))


## ---------------- 玩法流程 ----------------

func _on_fire_pressed(_text: String = "") -> void:  # 兼容 LineEdit.text_submitted 传入的文本
	if _phase != Phase.SELECT:
		return
	var expr := formula_input.text.strip_edges()
	if expr.is_empty():
		status_label.text = "先输入一条函数（如 sin(x)+1）"
		return
	# 预检：求一次值，语法错误直接提示
	var probe := _eval_expr(expr, 1.0)
	if _parse_failed or is_nan(probe) or is_inf(probe):
		status_label.text = "公式无效：请检查输入（如 sin(x)+1）"
		return

	_player_expr = expr
	_phase = Phase.PLAYER_FIRE
	fire_button.disabled = true
	_player_path = _make_path(_player_expr, START_X_PLAYER, _player_y, 1.0)
	status_label.text = "发射！"
	await _animate_projectile(_player_path, Color(0.55, 0.85, 1.0))
	if _phase != Phase.PLAYER_FIRE:
		return

	var hit := _path_hits(_player_path, _world_to_screen(Vector2(START_X_AI, _ai_y)))
	if hit:
		_player_score += 1
		status_label.text = "命中！AI 的位置被击中了"
	else:
		status_label.text = "未命中…再想想函数"
	_update_score_label()
	if _player_score >= WIN_SCORE:
		_end_game(true)
		return

	await get_tree().create_timer(0.4).timeout
	await _ai_turn()


func _ai_turn() -> void:
	_phase = Phase.AI_THINK
	status_label.text = "AI 思考中…"
	await get_tree().create_timer(AI_THINK_TIME).timeout
	if _phase != Phase.AI_THINK:
		return

	_ai_expr = _generate_ai_expr()
	ai_status_label.text = "AI 函数：%s" % _ai_expr
	status_label.text = "AI 发射！"
	_phase = Phase.AI_FIRE
	_ai_path = _make_path(_ai_expr, START_X_AI, _ai_y, -1.0)
	await _animate_projectile(_ai_path, Color(1.0, 0.5, 0.5))
	if _phase != Phase.AI_FIRE:
		return

	var hit := _path_hits(_ai_path, _world_to_screen(Vector2(START_X_PLAYER, _player_y)))
	if hit:
		_ai_score += 1
		status_label.text = "你被击中了…"
	else:
		status_label.text = "AI 未命中，你的回合"
	_update_score_label()
	if _ai_score >= WIN_SCORE:
		_end_game(false)
		return

	await get_tree().create_timer(0.4).timeout
	_start_round()


func _generate_ai_expr() -> String:
	if randf() < AI_HIT_CHANCE:
		return _ai_aimed_expr()
	return _ai_random_expr()


## AI 瞄准版：构造一条函数，使 f(16) - f(0) = delta（delta = 对方高度 - 自身高度）。
## 常数项会因「相对出发点」而抵消，因此只生成无常数项的形状。
func _ai_aimed_expr() -> String:
	var delta := _player_y - _ai_y
	match randi_range(0, 5):
		0:
			return _compose([[delta / 16.0, "x"]])
		1:
			return _compose([[delta / 256.0, "x^2"]])
		2:
			return _compose([[delta / 16.0, "abs(x)"]])
		3:
			return _trig_expr(delta, false)
		4:
			return _trig_expr(delta, true)
		_:
			var h := 0.0
			var denom := 0.0
			for i in range(20):
				h = randf_range(0.0, 16.0)
				denom = 256.0 - 32.0 * h
				if absf(denom) > 40.0:
					break
			return _compose([[delta / denom, "(x-%.3f)^2" % h]])


func _trig_expr(delta: float, use_cos: bool) -> String:
	var b := 0.0
	var denom := 0.0
	for i in range(20):
		b = randf_range(0.05, 2.0)
		denom = (cos(b * 16.0) - 1.0) if use_cos else sin(b * 16.0)
		if absf(denom) > 0.25:
			break
	var a := clampf(delta / denom, -6.0, 6.0)
	var unit := "cos(%.3f*x)" % b if use_cos else "sin(%.3f*x)" % b
	return _compose([[a, unit]])


func _ai_random_expr() -> String:
	match randi_range(0, 5):
		0:
			return _compose([[randf_range(-0.6, 0.6), "x"], [randf_range(-4.0, 4.0), ""]])
		1:
			return _compose([[randf_range(-0.12, 0.12), "x^2"], [randf_range(-4.0, 4.0), ""]])
		2:
			return _compose([[randf_range(-0.6, 0.6), "abs(x)"], [randf_range(-4.0, 4.0), ""]])
		3:
			return _compose([[randf_range(-3.0, 3.0), "sin(%.3f*x)" % randf_range(0.05, 2.0)], [randf_range(-1.0, 1.0), ""]])
		4:
			return _compose([[randf_range(-3.0, 3.0), "cos(%.3f*x)" % randf_range(0.05, 2.0)], [randf_range(-1.0, 1.0), ""]])
		_:
			return _compose([[randf_range(-0.1, 0.1), "(x-%.3f)^2" % randf_range(0.0, 16.0)], [randf_range(-4.0, 4.0), ""]])


## 把 [系数, 后缀] 拼成表达式字符串，如 [[0.25,"x"],[-3,""]] -> "0.250x - 3.000"
func _compose(terms: Array) -> String:
	var s := ""
	for term in terms:
		var v: float = term[0]
		var unit: String = term[1]
		if absf(v) < 0.0004:
			continue
		var part := "%.3f%s" % [absf(v), unit]
		if s.is_empty():
			s = ("-" if v < 0.0 else "") + part
		else:
			s += (" - " if v < 0.0 else " + ") + part
	return s if not s.is_empty() else "0"


## ---------------- 函数求值（简易解析器） ----------------

func _eval_expr(expr: String, x: float) -> float:
	_parse_failed = false
	_tokens = _tokenize(expr)
	if _parse_failed or _tokens.is_empty():
		return NAN
	_token_i = 0
	var v := _parse_add(x)
	if _parse_failed or _token_i < _tokens.size():
		return NAN
	return v


func _tokenize(expr: String) -> Array:
	var result: Array = []
	var i := 0
	while i < expr.length():
		var ch := expr[i]
		if ch == " " or ch == "\t":
			i += 1
			continue
		if _is_digit(ch) or ch == ".":
			var j := i
			var has_digit := false
			while j < expr.length() and (_is_digit(expr[j]) or expr[j] == "."):
				if _is_digit(expr[j]):
					has_digit = true
				j += 1
			if not has_digit:
				_parse_failed = true
				return []
			result.append({"type": "num", "value": expr.substr(i, j - i).to_float()})
			i = j
			continue
		if _is_letter(ch) or ch == "_":
			var j := i
			while j < expr.length() and (_is_letter(expr[j]) or _is_digit(expr[j]) or expr[j] == "_"):
				j += 1
			var name := expr.substr(i, j - i)
			i = j
			if name == "x":
				result.append({"type": "var", "value": name})
			elif name == "pi":
				result.append({"type": "num", "value": PI})
			elif name in ["sin", "cos", "tan", "abs", "sqrt", "log", "ln", "exp"]:
				result.append({"type": "func", "value": name})
			else:
				_parse_failed = true
				return []
			continue
		match ch:
			"(":
				result.append({"type": "lparen"})
			")":
				result.append({"type": "rparen"})
			"+", "-", "*", "/", "^":
				result.append({"type": "op", "value": ch})
			_:
				_parse_failed = true
				return []
		i += 1
	return result


func _parse_add(x: float) -> float:
	var v := _parse_mul(x)
	while not _parse_failed:
		var t := _peek()
		if t["type"] != "op" or (t["value"] != "+" and t["value"] != "-"):
			break
		_next()
		var rhs := _parse_mul(x)
		if _parse_failed:
			return NAN
		v = v + rhs if t["value"] == "+" else v - rhs
	return v


func _parse_mul(x: float) -> float:
	var v := _parse_unary(x)
	while not _parse_failed:
		var t := _peek()
		if t["type"] == "op" and (t["value"] == "*" or t["value"] == "/"):
			_next()
			var rhs := _parse_unary(x)
			if _parse_failed:
				return NAN
			v = v * rhs if t["value"] == "*" else v / rhs
			continue
		if t["type"] in ["var", "num", "lparen", "func"]:
			# 隐式乘法：0.5x、2sin(x)、(x+1)(x-1)
			var rhs := _parse_unary(x)
			if _parse_failed:
				return NAN
			v *= rhs
			continue
		break
	return v


func _parse_unary(x: float) -> float:
	var t := _peek()
	if t["type"] == "op" and t["value"] == "-":
		_next()
		return -_parse_unary(x)
	return _parse_power(x)


func _parse_power(x: float) -> float:
	var base := _parse_atom(x)
	if _parse_failed:
		return NAN
	var t := _peek()
	if t["type"] == "op" and t["value"] == "^":
		_next()
		var exponent := _parse_unary(x)
		if _parse_failed:
			return NAN
		return pow(base, exponent)
	return base


func _parse_atom(x: float) -> float:
	var t := _next()
	if _parse_failed:
		return NAN
	match t["type"]:
		"num":
			return t["value"]
		"var":
			return x
		"func":
			var open := _next()
			if open["type"] != "lparen":
				_parse_failed = true
				return NAN
			var arg := _parse_add(x)
			if _parse_failed:
				return NAN
			var close := _next()
			if close["type"] != "rparen":
				_parse_failed = true
				return NAN
			return _apply_func(t["value"], arg)
		"lparen":
			var v := _parse_add(x)
			if _parse_failed:
				return NAN
			var close := _next()
			if close["type"] != "rparen":
				_parse_failed = true
				return NAN
			return v
		_:
			_parse_failed = true
			return NAN


func _apply_func(name: String, v: float) -> float:
	match name:
		"sin":
			return sin(v)
		"cos":
			return cos(v)
		"tan":
			return tan(v)
		"abs":
			return absf(v)
		"sqrt":
			return sqrt(v)
		"log", "ln":
			return log(v)
		"exp":
			return exp(v)
		_:
			_parse_failed = true
			return NAN


func _peek() -> Dictionary:
	if _token_i < _tokens.size():
		return _tokens[_token_i]
	return {"type": "eof"}


func _next() -> Dictionary:
	var t := _peek()
	if _token_i < _tokens.size():
		_token_i += 1
	return t


func _is_digit(ch: String) -> bool:
	return ch >= "0" and ch <= "9"


func _is_letter(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z")


## ---------------- 路径 / 命中 ----------------

func _make_path(expr: String, start_x: float, start_y: float, dir: float) -> PackedVector2Array:
	var points: Array[Vector2] = []
	# 曲线相对出发点：起点固定为 (start_x, start_y)，形状 = f(x) - f(0)
	var base := _eval_expr(expr, 0.0)
	if _parse_failed or is_nan(base) or is_inf(base):
		return PackedVector2Array()
	var t := 0.0
	while t <= MAX_TRAVEL + 0.001:
		var y_off := _eval_expr(expr, t)
		if _parse_failed:
			break
		if is_nan(y_off) or is_inf(y_off) or absf(y_off) > 40.0:
			break
		var x := start_x + dir * t
		if x < X_MIN or x > X_MAX:
			break
		var y := start_y + (y_off - base)
		points.append(_world_to_screen(Vector2(x, clampf(y, Y_MIN - 2.0, Y_MAX + 2.0))))
		t += 0.05
	return PackedVector2Array(points)


func _path_hits(path: PackedVector2Array, target: Vector2) -> bool:
	if path.size() < 2:
		return false
	for i in range(path.size() - 1):
		if _distance_to_segment(target, path[i], path[i + 1]) <= HIT_RADIUS_PX:
			return true
	return false


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _animate_projectile(path: PackedVector2Array, color: Color) -> void:
	_active_path = path
	_active_color = color
	_anim_progress = 0.0
	var tween := create_tween()
	tween.tween_method(_set_anim_progress, 0.0, 1.0, SHOT_DURATION)
	await tween.finished
	_active_path = PackedVector2Array()
	_ball_pos = Vector2.ZERO
	queue_redraw()


func _set_anim_progress(value: float) -> void:
	_anim_progress = value
	if not _active_path.is_empty():
		_ball_pos = _point_on_path(_active_path, value)
	queue_redraw()


func _point_on_path(path: PackedVector2Array, t: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	var f := clampf(t, 0.0, 1.0) * (path.size() - 1)
	var i := int(f)
	var frac := f - i
	if i >= path.size() - 1:
		return path[path.size() - 1]
	return path[i].lerp(path[i + 1], frac)


## ---------------- 结算 / 重开 / 教程 ----------------

func _end_game(player_won: bool) -> void:
	_phase = Phase.GAME_OVER
	fire_button.disabled = true
	var message := "你赢了！" if player_won else "AI 赢了"
	status_label.text = message
	result_label.text = message
	result_panel.visible = true
	var result := "win" if player_won else "lose"
	game_finished.emit(result)
	if player_won:
		_on_game_won()
	else:
		_on_game_lost()


func _on_game_won() -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	var delta := GameManager.on_game_finished(char_id, "win")
	MemoryManager.record_daily_event(char_id, "graphwar", "win")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[Graphwar] 胜利，好感度 +%d" % delta)


func _on_game_lost() -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	GameManager.on_game_finished(char_id, "lose")
	MemoryManager.record_daily_event(char_id, "graphwar", "lose")
	print("[Graphwar] 失败接口预留")


func _start_round() -> void:
	_phase = Phase.SELECT
	_player_y = randf_range(-3.0, 3.0)
	_ai_y = randf_range(-3.0, 3.0)
	_player_path = PackedVector2Array()
	_ai_path = PackedVector2Array()
	_active_path = PackedVector2Array()
	_ball_pos = Vector2.ZERO
	fire_button.disabled = false
	ai_status_label.text = ""
	status_label.text = "你的回合：输入函数 f(x) 后回车或点「开火」"
	_update_score_label()
	queue_redraw()


func _update_score_label() -> void:
	score_label.text = "你 %d : %d AI" % [_player_score, _ai_score]


func _on_tutorial_pressed() -> void:
	tutorial_panel.visible = not tutorial_panel.visible


func _on_restart_pressed() -> void:
	_reset_match()


func _on_restart_result_pressed() -> void:
	_reset_match()


func _reset_match() -> void:
	_player_score = 0
	_ai_score = 0
	result_panel.visible = false
	game_restarted.emit()
	_start_round()


func _on_back_pressed() -> void:
	game_exited.emit()
	back_requested.emit()


func _on_exit_result_pressed() -> void:
	game_exited.emit()
	back_requested.emit()


func _world_to_screen(v: Vector2) -> Vector2:
	var nx := (v.x - X_MIN) / (X_MAX - X_MIN)
	var ny := (Y_MAX - v.y) / (Y_MAX - Y_MIN)
	return BOARD_RECT.position + Vector2(nx * BOARD_RECT.size.x, ny * BOARD_RECT.size.y)
