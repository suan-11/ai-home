extends Control
## P3：Graphwar 仿·函数对打（多球 + 障碍 + 拖尾轨迹版）
## 双方各 3 个球：玩家（左侧蓝菱形）vs AI（右侧红圆）。
## 每回合从自己剩余的球中选一个，输入函数 f(x) 发射（x = 离开出发点的水平距离，
## 曲线相对出发点：y = 出发高度 + f(x) − f(0)）；轨迹随炮弹移动逐步显示。
## 命中对方球即击毁它，场上的随机球形障碍会挡住炮弹（被撞后消失）；
## 先击毁对方全部 3 球的一方获胜。胜负沿用通用规则（胜 +3 / 平 +1 / 负 0）。

signal back_requested
signal game_finished(result: String)
signal game_restarted
signal game_exited

const WIN_BALLS := 3
const AI_AIM_CHANCE := 0.65
const AI_AIM_JITTER := 1.2
const AI_THINK_TIME := 0.7
const SHOT_DURATION := 0.9
const STEP := 0.4
const MAX_TRAVEL := 120.0
const BALL_HIT_PX := 9.0

const X_MIN := -50.0
const X_MAX := 50.0
const Y_MIN := -25.0
const Y_MAX := 25.0
const BOARD_RECT := Rect2(10, 56, 288, 158)

enum Phase { SELECT, PLAYER_FIRE, AI_THINK, AI_FIRE, GAME_OVER }

var _phase: int = Phase.SELECT
var _player_kills := 0
var _ai_kills := 0
var _balls_player: Array = []
var _balls_ai: Array = []
var _obstacles: Array = []
var _selected_ball := 0
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
@onready var formula_input: LineEdit = $BottomBar/FormulaInput
@onready var fire_button: Button = $BottomBar/FireButton
@onready var ai_status_label: Label = $Controls/AiStatusLabel
@onready var tutorial_button: Button = $BottomBar/TutorialButton
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
	_start_match()


func _gui_input(event: InputEvent) -> void:
	if _phase != Phase.SELECT:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _ball_at_screen(event.position)
		if idx >= 0:
			_selected_ball = idx
			status_label.text = "已选择球 %d（输入函数后开火）" % (idx + 1)
			queue_redraw()


## ---------------- 绘制 ----------------

func _draw() -> void:
	var app_rect := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	draw_rect(app_rect, Color(0.12, 0.15, 0.21))
	draw_rect(Rect2(Vector2(6, 6), Vector2(app_rect.size.x, 30)), Color(0.09, 0.11, 0.16))

	draw_rect(BOARD_RECT, Color(0.16, 0.19, 0.27))
	draw_rect(BOARD_RECT, Color(0.30, 0.35, 0.45), false, 1.0)

	var grid_color := Color(0.35, 0.40, 0.50, 0.35)
	for x in range(int(X_MIN), int(X_MAX) + 1, 10):
		draw_line(_world_to_screen(Vector2(x, Y_MIN)), _world_to_screen(Vector2(x, Y_MAX)), grid_color, 1.0)
	for y in range(int(Y_MIN), int(Y_MAX) + 1, 5):
		draw_line(_world_to_screen(Vector2(X_MIN, y)), _world_to_screen(Vector2(X_MAX, y)), grid_color, 1.0)

	var axis_color := Color(0.50, 0.55, 0.65)
	draw_line(_world_to_screen(Vector2(X_MIN, 0)), _world_to_screen(Vector2(X_MAX, 0)), axis_color, 1.4)
	draw_line(_world_to_screen(Vector2(0, Y_MIN)), _world_to_screen(Vector2(0, Y_MAX)), axis_color, 1.4)

	# 随机球形障碍
	for o in _obstacles:
		draw_circle(o["pos"], o["r"], Color(0.42, 0.34, 0.30, 0.40))
		draw_arc(o["pos"], o["r"], 0.0, TAU, 32, Color(0.62, 0.52, 0.44), 1.5)

	# 双方球
	_draw_balls(false)
	_draw_balls(true)

	# 轨迹：发射中只绘制已走部分，完成后显示整条
	if _phase == Phase.PLAYER_FIRE and _active_path == _player_path:
		_draw_trajectory(_player_path, Color(0.55, 0.85, 1.0), _anim_progress)
	elif _player_path.size() > 1:
		_draw_trajectory(_player_path, Color(0.55, 0.85, 1.0))
	if _phase == Phase.AI_FIRE and _active_path == _ai_path:
		_draw_trajectory(_ai_path, Color(1.0, 0.5, 0.5), _anim_progress)
	elif _ai_path.size() > 1:
		_draw_trajectory(_ai_path, Color(1.0, 0.5, 0.5))

	# 飞行中的小球（直径 ≈ 函数线段宽度的 2 倍：线宽 2px → 球直径 4px）
	if not _active_path.is_empty() and _anim_progress < 1.0:
		draw_circle(_ball_pos, 2.0, _active_color)


func _draw_balls(is_ai: bool) -> void:
	var balls := _balls_ai if is_ai else _balls_player
	for i in range(balls.size()):
		var ball: Dictionary = balls[i]
		if not ball["alive"]:
			continue
		var center := _world_to_screen(ball["pos"])
		if is_ai:
			draw_circle(center, 7.0, Color(1.0, 0.45, 0.45))
			draw_circle(center, 2.5, Color(1.0, 0.85, 0.85))
			draw_string(ThemeDB.fallback_font, center + Vector2(-5, 18), "AI%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.7, 0.7))
		else:
			var pts := PackedVector2Array([
				center + Vector2(0, -7), center + Vector2(6, 0),
				center + Vector2(0, 7), center + Vector2(-6, 0),
			])
			for k in range(4):
				draw_line(pts[k], pts[(k + 1) % 4], Color(0.45, 0.75, 1.0), 2.0)
			draw_circle(center, 2.0, Color(0.55, 0.85, 1.0))
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 18), "你%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.85, 1.0))
			if i == _selected_ball and _phase == Phase.SELECT:
				draw_arc(center, 11.0, 0.0, TAU, 24, Color.WHITE, 1.5)


func _draw_trajectory(path: PackedVector2Array, color: Color, progress: float = -1.0) -> void:
	if path.size() < 2:
		return
	if progress < 0.0:
		draw_polyline(path, color, 2.0)
		return
	var n := clampi(int(round(progress * (path.size() - 1))), 1, path.size() - 1)
	var sub := PackedVector2Array()
	for i in range(n + 1):
		sub.append(path[i])
	if sub.size() > 1:
		draw_polyline(sub, color, 2.0)


## ---------------- 玩法流程 ----------------

func _on_fire_pressed(_text: String = "") -> void:  # 兼容 LineEdit.text_submitted
	if _phase != Phase.SELECT:
		return
	var ball: Dictionary = _balls_player[_selected_ball]
	if not ball["alive"]:
		status_label.text = "该球已发射/被毁，请点击其它球"
		return
	var expr := formula_input.text.strip_edges()
	if expr.is_empty():
		status_label.text = "先输入一条函数（如 sin(x)+1）"
		return
	var probe := _eval_expr(expr, 1.0)
	if _parse_failed or is_nan(probe) or is_inf(probe):
		status_label.text = "公式无效：请检查输入（如 sin(x)+1）"
		return

	_player_expr = expr
	_phase = Phase.PLAYER_FIRE
	fire_button.disabled = true
	var path_result := _build_shot(_player_expr, ball["pos"], 1.0, true)
	_player_path = path_result["path"]
	status_label.text = "发射！球 %d 出发了（发射后仍在场）" % (_selected_ball + 1)
	await _animate_projectile(_player_path, Color(0.55, 0.85, 1.0))
	if _phase != Phase.PLAYER_FIRE:
		return

	_apply_shot_result(path_result, true)
	if _check_player_win():
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

	var shot := _ai_shot()
	_ai_expr = shot["expr"]
	var ball_index: int = shot["ball_index"]
	var ball_pos: Vector2 = _balls_ai[ball_index]["pos"]
	status_label.text = "AI 使用了「%s」（球 %d）" % [_ai_expr, ball_index + 1]
	_phase = Phase.AI_FIRE
	var path_result := _build_shot(_ai_expr, ball_pos, -1.0, false)
	_ai_path = path_result["path"]
	await _animate_projectile(_ai_path, Color(1.0, 0.5, 0.5))
	if _phase != Phase.AI_FIRE:
		return

	_apply_shot_result(path_result, false)
	if _check_ai_win():
		_end_game(false)
		return

	await get_tree().create_timer(0.4).timeout
	_start_round()


## 根据发射后的路径结算：击中的球全部被摧毁（炮弹穿透不消失），障碍挡住则被清除。
func _apply_shot_result(result: Dictionary, is_player: bool) -> void:
	var balls := _balls_ai if is_player else _balls_player
	var parts: Array[String] = []
	var hits: Array = result["enemies"]
	if hits.size() > 0:
		var names: Array[String] = []
		for idx in hits:
			balls[idx]["alive"] = false
			if is_player:
				_player_kills += 1
			else:
				_ai_kills += 1
			names.append("球 %d" % (idx + 1))
		if is_player:
			parts.append("命中！击毁 AI 的%s" % _join_strings(names, "、"))
		else:
			parts.append("你被击中了：%s" % _join_strings(names, "、"))
	if result["obstacle"] >= 0:
		_obstacles.remove_at(result["obstacle"])
		parts.append("撞上球形障碍被挡住（障碍已清除）")
	if parts.is_empty():
		parts.append("未命中…再想想函数")
	status_label.text = _join_strings(parts, "；")
	_update_score_label()


func _join_strings(arr: Array, sep: String) -> String:
	var s := ""
	for i in range(arr.size()):
		if i > 0:
			s += sep
		s += str(arr[i])
	return s


func _check_player_win() -> bool:
	for b in _balls_ai:
		if b["alive"]:
			return false
	return true


func _check_ai_win() -> bool:
	for b in _balls_player:
		if b["alive"]:
			return false
	return true


## AI 出招：随机选一个自己的球 + 随机瞄一个对方球；瞄准时加随机偏移。
func _ai_shot() -> Dictionary:
	var shooter_index := _random_alive_index(_balls_ai)
	var target_index := _random_alive_index(_balls_player)
	var shooter_pos: Vector2 = _balls_ai[shooter_index]["pos"]
	var target_pos: Vector2 = _balls_player[target_index]["pos"]
	var dist := shooter_pos.x - target_pos.x  # 正数
	var delta := target_pos.y - shooter_pos.y
	var expr := ""
	if randf() < AI_AIM_CHANCE:
		# 给目标坐标/结果加随机偏移
		var jitter := randf_range(-AI_AIM_JITTER, AI_AIM_JITTER)
		expr = _solve_expr(dist, delta + jitter)
	else:
		expr = _ai_random_expr()
	return {"expr": expr, "ball_index": shooter_index}


func _solve_expr(dist: float, delta: float) -> String:
	match randi_range(0, 5):
		0:
			return _compose([[delta / dist, "x"]])
		1:
			return _compose([[delta / (dist * dist), "x^2"]])
		2:
			return _compose([[delta / dist, "abs(x)"]])
		3:
			return _trig_expr(dist, delta, false)
		4:
			return _trig_expr(dist, delta, true)
		_:
			var h := 0.0
			var denom := 0.0
			for i in range(20):
				h = randf_range(0.0, dist)
				denom = dist * dist - 2.0 * dist * h
				if absf(denom) > 0.15 * dist * dist:
					break
			return _compose([[delta / denom, "(x-%.3f)^2" % h]])


func _trig_expr(dist: float, delta: float, use_cos: bool) -> String:
	var b := 0.0
	var denom := 0.0
	for i in range(20):
		b = randf_range(0.02, 0.6)
		denom = (cos(b * dist) - 1.0) if use_cos else sin(b * dist)
		if absf(denom) > 0.25:
			break
	var a := clampf(delta / denom, -6.0, 6.0)
	var unit := "cos(%.3f*x)" % b if use_cos else "sin(%.3f*x)" % b
	return _compose([[a, unit]])


func _ai_random_expr() -> String:
	match randi_range(0, 5):
		0:
			return _compose([[randf_range(-1.0, 1.0), "x"]])
		1:
			return _compose([[randf_range(-0.2, 0.2), "x^2"]])
		2:
			return _compose([[randf_range(-1.0, 1.0), "abs(x)"]])
		3:
			return _compose([[randf_range(-6.0, 6.0), "sin(%.3f*x)" % randf_range(0.02, 0.6)]])
		4:
			return _compose([[randf_range(-6.0, 6.0), "cos(%.3f*x)" % randf_range(0.02, 0.6)]])
		_:
			return _compose([[randf_range(-0.5, 0.5), "(x-%.3f)^2" % randf_range(10.0, 70.0)]])


## 把 [系数, 后缀] 拼成表达式字符串。
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


## ---------------- 轨迹构建（含障碍/对方球碰撞） ----------------

## 从 start_world 出发沿函数建轨迹；碰到障碍或屏幕边缘才截断。
## 命中对方球不停止炮弹（可连穿多个球），记录所有被击中的球。
## 返回 {path, enemies: Array[索引], obstacle: -1 或索引}。
func _build_shot(expr: String, start_world: Vector2, dir: float, is_player: bool) -> Dictionary:
	var result := {
		"path": PackedVector2Array(), "enemies": [], "obstacle": -1,
	}
	var enemy_balls := _balls_ai if is_player else _balls_player
	var base := _eval_expr(expr, 0.0)
	if _parse_failed or is_nan(base) or is_inf(base):
		return result
	var points: Array[Vector2] = []
	var prev := _world_to_screen(start_world)
	points.append(prev)
	var t := 0.0
	while t <= MAX_TRAVEL + 0.001:
		var y_off := _eval_expr(expr, t)
		if _parse_failed or is_nan(y_off) or is_inf(y_off) or absf(y_off) > 80.0:
			break
		var w := Vector2(start_world.x + dir * t, start_world.y + (y_off - base))
		if w.x < X_MIN or w.x > X_MAX or absf(w.y) > Y_MAX * 2.0:
			break
		var s := _world_to_screen(w)
		# 命中对方球：记录但不停止炮弹（穿透）
		for i in range(enemy_balls.size()):
			var eb: Dictionary = enemy_balls[i]
			if not eb["alive"] or result["enemies"].has(i):
				continue
			if _segment_circle(prev, s, _world_to_screen(eb["pos"]), BALL_HIT_PX) >= 0.0:
				result["enemies"].append(i)
		# 障碍：挡住并截断
		var best_t := 1.0
		var best_obstacle := -1
		for i in range(_obstacles.size()):
			var o: Dictionary = _obstacles[i]
			var tt := _segment_circle(prev, s, o["pos"], o["r"])
			if tt >= 0.0 and tt < best_t:
				best_t = tt
				best_obstacle = i
		if best_obstacle >= 0:
			points.append(prev.lerp(s, best_t))
			result["obstacle"] = best_obstacle
			break
		points.append(s)
		prev = s
		t += STEP
	result["path"] = PackedVector2Array(points)
	return result


## 线段 a->b 与圆 (c, r) 的第一交点参数 t∈[0,1]；无交返回 -1。
func _segment_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> float:
	var d := b - a
	var m := a - c
	var A := d.dot(d)
	if A < 0.0001:
		return -1.0
	var B := 2.0 * m.dot(d)
	var C := m.dot(m) - r * r
	var disc := B * B - 4.0 * A * C
	if disc < 0.0:
		return -1.0
	var sq := sqrt(disc)
	var t1 := (-B - sq) / (2.0 * A)
	if t1 >= 0.0 and t1 <= 1.0:
		return t1
	var t2 := (-B + sq) / (2.0 * A)
	if t2 >= 0.0 and t2 <= 1.0:
		return t2
	return -1.0


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


## ---------------- 动画 / 辅助 ----------------

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


func _ball_at_screen(pos: Vector2) -> int:
	var best := -1
	var best_dist := 16.0
	for i in range(_balls_player.size()):
		var ball: Dictionary = _balls_player[i]
		if not ball["alive"]:
			continue
		var d := pos.distance_to(_world_to_screen(ball["pos"]))
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _random_alive_index(balls: Array) -> int:
	var alive: Array = []
	for i in range(balls.size()):
		if balls[i]["alive"]:
			alive.append(i)
	if alive.is_empty():
		return 0
	return alive[randi_range(0, alive.size() - 1)]


## ---------------- 生成 / 匹配管理 ----------------

func _start_match() -> void:
	_player_kills = 0
	_ai_kills = 0
	_balls_player = _spawn_balls(true)
	_balls_ai = _spawn_balls(false)
	_obstacles = _spawn_obstacles()
	_selected_ball = _first_alive_player_ball()
	_result_panel_hide()
	_start_round()


func _spawn_balls(is_player: bool) -> Array:
	var xs: Array = [-38.0, -27.0, -16.0] if is_player else [16.0, 27.0, 38.0]
	var result: Array = []
	for i in range(3):
		var x: float = xs[i] + randf_range(-3.0, 3.0)
		var y: float = randf_range(-14.0, 14.0)
		result.append({"pos": Vector2(x, y), "alive": true})
	return result


func _spawn_obstacles() -> Array:
	var result: Array = []
	var count := randi_range(6, 10)
	for attempt in range(80):
		if result.size() >= count:
			break
		var r := randf_range(9.0, 16.0)
		var pos := Vector2(
			randf_range(BOARD_RECT.position.x + 20.0, BOARD_RECT.end.x - 20.0),
			randf_range(BOARD_RECT.position.y + 20.0, BOARD_RECT.end.y - 20.0)
		)
		var ok := true
		for b in _balls_player + _balls_ai:
			if pos.distance_to(_world_to_screen(b["pos"])) < r + 18.0:
				ok = false
				break
		if ok:
			for o in result:
				if pos.distance_to(o["pos"]) < r + o["r"] + 6.0:
					ok = false
					break
		if ok:
			result.append({"pos": pos, "r": r})
	return result


func _first_alive_player_ball() -> int:
	for i in range(_balls_player.size()):
		if _balls_player[i]["alive"]:
			return i
	return 0


func _start_round() -> void:
	_phase = Phase.SELECT
	_player_path = PackedVector2Array()
	_ai_path = PackedVector2Array()
	_active_path = PackedVector2Array()
	_ball_pos = Vector2.ZERO
	fire_button.disabled = false
	_selected_ball = _first_alive_player_ball()
	status_label.text = "你的回合：已选球 %d，输入函数后开火（球发射后仍在场）" % (_selected_ball + 1)
	_update_score_label()
	queue_redraw()


func _update_score_label() -> void:
	score_label.text = "击毁 %d/3 : %d/3" % [_player_kills, _ai_kills]


func _result_panel_hide() -> void:
	result_panel.visible = false


func _on_tutorial_pressed() -> void:
	tutorial_panel.visible = not tutorial_panel.visible


func _on_restart_pressed() -> void:
	_reset_match()


func _on_restart_result_pressed() -> void:
	_reset_match()


func _reset_match() -> void:
	game_restarted.emit()
	_start_match()


func _on_back_pressed() -> void:
	game_exited.emit()
	back_requested.emit()


func _on_exit_result_pressed() -> void:
	game_exited.emit()
	back_requested.emit()


## ---------------- 结算 ----------------

func _end_game(player_won: bool) -> void:
	_phase = Phase.GAME_OVER
	fire_button.disabled = true
	var message := "你赢了！击毁全部 3 球" if player_won else "AI 赢了…你的 3 球被击毁"
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


func _world_to_screen(v: Vector2) -> Vector2:
	var nx := (v.x - X_MIN) / (X_MAX - X_MIN)
	var ny := (Y_MAX - v.y) / (Y_MAX - Y_MIN)
	return BOARD_RECT.position + Vector2(nx * BOARD_RECT.size.x, ny * BOARD_RECT.size.y)
