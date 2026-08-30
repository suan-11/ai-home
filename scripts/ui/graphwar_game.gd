extends Control
## P3：Graphwar 仿·函数对打（简化回合制）
## 玩家与 AI 轮流用预设函数卡发射小球：小球沿函数曲线飞行，
## 命中对方目标点得 1 分，先得 WIN_SCORE 分获胜。
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
const AI_SOLVE_JITTER := 0.08

const X_MIN := -10.0
const X_MAX := 10.0
const Y_MIN := -5.0
const Y_MAX := 5.0
const TARGET_X_PLAYER := -8.0
const TARGET_X_AI := 8.0
const BOARD_RECT := Rect2(10, 36, 288, 222)

## 预设函数卡（单一数据源）。params: key/label/min/max/default/step。
const CARDS := [
	{
		"name": "直线", "formula": "y = a·x + b",
		"params": [
			{"key": "a", "label": "a", "min": -1.0, "max": 1.0, "default": 0.3, "step": 0.01},
			{"key": "b", "label": "b", "min": -4.0, "max": 4.0, "default": -2.0, "step": 0.01},
		],
	},
	{
		"name": "抛物线", "formula": "y = a·x² + b",
		"params": [
			{"key": "a", "label": "a", "min": -0.4, "max": 0.4, "default": 0.1, "step": 0.01},
			{"key": "b", "label": "b", "min": -4.0, "max": 4.0, "default": -3.0, "step": 0.01},
		],
	},
	{
		"name": "绝对值", "formula": "y = a·|x| + b",
		"params": [
			{"key": "a", "label": "a", "min": -1.0, "max": 1.0, "default": 0.3, "step": 0.01},
			{"key": "b", "label": "b", "min": -4.0, "max": 4.0, "default": -2.0, "step": 0.01},
		],
	},
	{
		"name": "正弦", "formula": "y = a·sin(b·x)",
		"params": [
			{"key": "a", "label": "a", "min": -3.0, "max": 3.0, "default": 1.2, "step": 0.05},
			{"key": "b", "label": "b", "min": 0.05, "max": 2.0, "default": 0.4, "step": 0.01},
		],
	},
	{
		"name": "余弦", "formula": "y = a·cos(b·x)",
		"params": [
			{"key": "a", "label": "a", "min": -3.0, "max": 3.0, "default": 1.2, "step": 0.05},
			{"key": "b", "label": "b", "min": 0.05, "max": 2.0, "default": 0.4, "step": 0.01},
		],
	},
	{
		"name": "三次曲线", "formula": "y = a·x³ + b",
		"params": [
			{"key": "a", "label": "a", "min": -0.1, "max": 0.1, "default": 0.02, "step": 0.001},
			{"key": "b", "label": "b", "min": -4.0, "max": 4.0, "default": -2.0, "step": 0.01},
		],
	},
	{
		"name": "顶点式抛物线", "formula": "y = a·(x-h)² + v",
		"params": [
			{"key": "a", "label": "a", "min": -0.3, "max": 0.3, "default": 0.1, "step": 0.01},
			{"key": "h", "label": "h", "min": -9.0, "max": 9.0, "default": 0.0, "step": 0.1},
			{"key": "v", "label": "v", "min": -4.0, "max": 4.0, "default": -1.0, "step": 0.01},
		],
	},
	{
		"name": "任意抛物线", "formula": "y = a·x² + b·x + c",
		"params": [
			{"key": "a", "label": "a", "min": -0.3, "max": 0.3, "default": 0.05, "step": 0.01},
			{"key": "b", "label": "b", "min": -1.0, "max": 1.0, "default": 0.0, "step": 0.01},
			{"key": "c", "label": "c", "min": -4.0, "max": 4.0, "default": -1.0, "step": 0.01},
		],
	},
]

enum Phase { SELECT, PLAYER_FIRE, AI_THINK, AI_FIRE, GAME_OVER }

var _phase: int = Phase.SELECT
var _player_score := 0
var _ai_score := 0
var _target_y := 0.0
var _card_index := 0
var _params: Array = []
var _ai_card_index := 0
var _ai_params: Array = []
var _preview_path := PackedVector2Array()
var _player_path := PackedVector2Array()
var _ai_path := PackedVector2Array()
var _active_path := PackedVector2Array()
var _active_color := Color.WHITE
var _anim_progress := 0.0
var _ball_pos := Vector2.ZERO

@onready var status_label: Label = $StatusLabel
@onready var score_label: Label = $ScoreLabel
@onready var card_option: OptionButton = $Controls/CardOption
@onready var param_labels: Array[Label] = [
	$Controls/Param0Label, $Controls/Param1Label, $Controls/Param2Label,
]
@onready var param_sliders: Array[HSlider] = [
	$Controls/Param0Slider, $Controls/Param1Slider, $Controls/Param2Slider,
]
@onready var fire_button: Button = $Controls/FireButton
@onready var ai_status_label: Label = $Controls/AiStatusLabel
@onready var restart_button: Button = $Controls/RestartButton
@onready var back_button: Button = $Controls/BackButton
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel
@onready var restart_result_button: Button = $ResultPanel/RestartResultButton
@onready var exit_result_button: Button = $ResultPanel/ExitResultButton


func _ready() -> void:
	result_panel.visible = false
	for card in CARDS:
		card_option.add_item(card["name"])
	card_option.item_selected.connect(_on_card_changed)
	for slider in param_sliders:
		slider.value_changed.connect(_on_param_changed)
	fire_button.pressed.connect(_on_fire_pressed)
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
		var p1 := _world_to_screen(Vector2(x, Y_MIN))
		var p2 := _world_to_screen(Vector2(x, Y_MAX))
		draw_line(p1, p2, grid_color, 1.0)
	for y in range(int(Y_MIN), int(Y_MAX) + 1, 1):
		var p1 := _world_to_screen(Vector2(X_MIN, y))
		var p2 := _world_to_screen(Vector2(X_MAX, y))
		draw_line(p1, p2, grid_color, 1.0)

	var axis_color := Color(0.50, 0.55, 0.65)
	draw_line(_world_to_screen(Vector2(X_MIN, 0)), _world_to_screen(Vector2(X_MAX, 0)), axis_color, 1.4)
	draw_line(_world_to_screen(Vector2(0, Y_MIN)), _world_to_screen(Vector2(0, Y_MAX)), axis_color, 1.4)

	# 目标点：玩家（左侧蓝菱形） vs AI（右侧红圆）
	_draw_player_target()
	_draw_ai_target()

	# 预览曲线（选卡/调参时）
	if _phase == Phase.SELECT and _preview_path.size() > 1:
		draw_polyline(_preview_path, Color(0.45, 0.65, 1.0, 0.45), 1.5)

	# 已发射轨迹
	if _player_path.size() > 1:
		draw_polyline(_player_path, Color(0.55, 0.85, 1.0), 2.0)
	if _ai_path.size() > 1:
		draw_polyline(_ai_path, Color(1.0, 0.5, 0.5), 2.0)

	# 飞行中的小球
	if not _active_path.is_empty() and _anim_progress < 1.0:
		draw_circle(_ball_pos, 4.0, _active_color)
		draw_circle(_ball_pos, 7.0, Color(_active_color.r, _active_color.g, _active_color.b, 0.3))


func _draw_player_target() -> void:
	var center := _world_to_screen(Vector2(TARGET_X_PLAYER, _target_y))
	var pts := PackedVector2Array([
		center + Vector2(0, -6), center + Vector2(5, 0),
		center + Vector2(0, 6), center + Vector2(-5, 0),
	])
	for i in range(4):
		draw_line(pts[i], pts[(i + 1) % 4], Color(0.45, 0.75, 1.0), 2.0)
	draw_circle(center, 2.0, Color(0.55, 0.85, 1.0))
	draw_string(ThemeDB.fallback_font, center + Vector2(-8, 18), "你", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.85, 1.0))


func _draw_ai_target() -> void:
	var center := _world_to_screen(Vector2(TARGET_X_AI, _target_y))
	draw_circle(center, 6.0, Color(1.0, 0.45, 0.45))
	draw_circle(center, 2.0, Color(1.0, 0.8, 0.8))
	draw_string(ThemeDB.fallback_font, center + Vector2(-4, 18), "AI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.7, 0.7))


func _on_card_changed(index: int) -> void:
	_card_index = index
	_params = _default_params(index)
	_update_param_ui()
	_refresh_preview()
	queue_redraw()


func _on_param_changed(_value: float) -> void:
	for i in range(_params.size()):
		if i < param_sliders.size():
			_params[i] = param_sliders[i].value
	_update_param_labels()
	_refresh_preview()
	queue_redraw()


func _on_fire_pressed() -> void:
	if _phase != Phase.SELECT:
		return
	_phase = Phase.PLAYER_FIRE
	card_option.disabled = true
	fire_button.disabled = true
	_player_path = _make_path(_card_index, _params, false)
	status_label.text = "发射！"
	await _animate_projectile(_player_path, Color(0.55, 0.85, 1.0))
	if _phase != Phase.PLAYER_FIRE:
		return

	var hit := _path_hits(_player_path, _world_to_screen(Vector2(TARGET_X_AI, _target_y)))
	if hit:
		_player_score += 1
		status_label.text = "命中！AI 的目标被击中了"
	else:
		status_label.text = "未命中…"
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

	var pick := _pick_ai_shot()
	_ai_card_index = pick["card_index"]
	_ai_params = pick["params"]
	var card_name: String = CARDS[_ai_card_index]["name"]
	ai_status_label.text = "AI 使用了「%s」" % card_name
	status_label.text = "AI 发射！"
	_phase = Phase.AI_FIRE
	_ai_path = _make_path(_ai_card_index, _ai_params, true)
	await _animate_projectile(_ai_path, Color(1.0, 0.5, 0.5))
	if _phase != Phase.AI_FIRE:
		return

	var hit := _path_hits(_ai_path, _world_to_screen(Vector2(TARGET_X_PLAYER, _target_y)))
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


func _pick_ai_shot() -> Dictionary:
	var hard := randf() < AI_HIT_CHANCE
	var index := randi_range(0, CARDS.size() - 1)
	var params: Array = _solve_for_target(index) if hard else _random_params(index)
	params = _clamp_params(index, params)
	return {"card_index": index, "params": params}


## 尝试生成能命中 AI 目标点（x=8, y=_target_y）的参数；三角函数用简单暴力搜索。
func _solve_for_target(index: int) -> Array:
	match index:
		0:
			var a := randf_range(-0.9, 0.9)
			return [a, _target_y - a * TARGET_X_AI + _jitter()]
		1:
			var a2 := randf_range(-0.35, 0.35)
			return [a2, _target_y - a2 * TARGET_X_AI * TARGET_X_AI + _jitter()]
		2:
			var a3 := randf_range(-0.9, 0.9)
			return [a3, _target_y - a3 * absf(TARGET_X_AI) + _jitter()]
		3, 4:
			return _best_random_trig(index)
		5:
			var a4 := randf_range(-0.09, 0.09)
			return [a4, _target_y - a4 * TARGET_X_AI * TARGET_X_AI * TARGET_X_AI + _jitter()]
		6:
			var a5 := randf_range(-0.25, 0.25)
			var h := randf_range(-6.0, 6.0)
			return [a5, h, _target_y - a5 * pow(TARGET_X_AI - h, 2) + _jitter()]
		_:
			var a6 := randf_range(-0.25, 0.25)
			var b6 := randf_range(-0.6, 0.6)
			return [a6, b6, _target_y - a6 * TARGET_X_AI * TARGET_X_AI - b6 * TARGET_X_AI + _jitter()]


func _best_random_trig(index: int) -> Array:
	var best: Array = _random_params(index)
	var best_err := INF
	for i in range(24):
		var p: Array = _random_params(index)
		var err := absf(_eval(index, p, TARGET_X_AI) - _target_y)
		if err < best_err:
			best_err = err
			best = p.duplicate()
	return best


func _jitter() -> float:
	return randf_range(-AI_SOLVE_JITTER, AI_SOLVE_JITTER)


func _random_params(index: int) -> Array:
	var defs: Array = CARDS[index]["params"]
	var result: Array = []
	for d in defs:
		result.append(randf_range(d["min"], d["max"]))
	return result


func _default_params(index: int) -> Array:
	var defs: Array = CARDS[index]["params"]
	var result: Array = []
	for d in defs:
		result.append(d["default"])
	return result


func _clamp_params(index: int, params: Array) -> Array:
	var defs: Array = CARDS[index]["params"]
	var result: Array = params.duplicate()
	for i in range(defs.size()):
		result[i] = clampf(result[i], defs[i]["min"], defs[i]["max"])
	return result


func _make_path(index: int, params: Array, reversed_dir: bool) -> PackedVector2Array:
	var points: Array[Vector2] = []
	var x := X_MIN
	while x <= X_MAX + 0.001:
		var y := _eval(index, params, x)
		if is_nan(y) or is_inf(y) or absf(y) > 40.0:
			break
		points.append(_world_to_screen(Vector2(x, clampf(y, Y_MIN - 2.0, Y_MAX + 2.0))))
		x += 0.05
	if reversed_dir:
		points.reverse()
	return PackedVector2Array(points)


func _eval(index: int, params: Array, x: float) -> float:
	match index:
		0:
			return params[0] * x + params[1]
		1:
			return params[0] * x * x + params[1]
		2:
			return params[0] * absf(x) + params[1]
		3:
			return params[0] * sin(params[1] * x)
		4:
			return params[0] * cos(params[1] * x)
		5:
			return params[0] * x * x * x + params[1]
		6:
			return params[0] * pow(x - params[1], 2) + params[2]
		_:
			return params[0] * x * x + params[1] * x + params[2]


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


func _end_game(player_won: bool) -> void:
	_phase = Phase.GAME_OVER
	card_option.disabled = true
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
	_target_y = randf_range(-3.0, 3.0)
	_player_path = PackedVector2Array()
	_ai_path = PackedVector2Array()
	_active_path = PackedVector2Array()
	_ball_pos = Vector2.ZERO
	card_option.disabled = false
	fire_button.disabled = false
	ai_status_label.text = ""
	status_label.text = "你的回合：选择函数卡并调参，点击「开火」"
	_update_score_label()
	_refresh_card_ui()
	_refresh_preview()
	queue_redraw()


func _refresh_card_ui() -> void:
	_params = _default_params(_card_index)
	_update_param_ui()


func _refresh_preview() -> void:
	_preview_path = _make_path(_card_index, _params, false)


func _update_param_ui() -> void:
	var defs: Array = CARDS[_card_index]["params"]
	for i in range(param_sliders.size()):
		var label := param_labels[i]
		var slider := param_sliders[i]
		if i < defs.size():
			label.visible = true
			slider.visible = true
			var d: Dictionary = defs[i]
			slider.min_value = d["min"]
			slider.max_value = d["max"]
			slider.step = d["step"]
			slider.set_value_no_signal(clampf(_params[i], d["min"], d["max"]))
		else:
			label.visible = false
			slider.visible = false
	_update_param_labels()


func _update_param_labels() -> void:
	var defs: Array = CARDS[_card_index]["params"]
	for i in range(param_labels.size()):
		var label := param_labels[i]
		if not label.visible:
			continue
		label.text = "%s = %.2f" % [defs[i]["key"], param_sliders[i].value]


func _update_score_label() -> void:
	score_label.text = "你 %d : %d AI" % [_player_score, _ai_score]


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
