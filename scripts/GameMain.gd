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
const PHONE_OVERLAY_SCENE := preload("res://scenes/ui/phone_overlay.tscn")
const BUBBLE_SCENE := preload("res://scenes/ui/bubble.tscn")
const NOTIFY_FX_SCENE := preload("res://scenes/ui/notify_fx.tscn")
const TOAST_SCENE := preload("res://scenes/ui/notification_toast.tscn")
const NOTIFY_SOUND_PATH := "res://assets/sfx/notify.wav"

## 预置吸引物：点击房间时放置，角色被吸引过去后消失。
const ATTRACT_ITEMS := [
	{"id": "heart", "name": "爱心"},
	{"id": "fish", "name": "小鱼干"},
	{"id": "apple", "name": "苹果"},
	{"id": "star", "name": "星星"},
	{"id": "ball", "name": "毛线球"},
	{"id": "book", "name": "书卷"},
]
const ATTRACT_ITEM_DEFAULT := "random"
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
	{"id": "fridge", "name": "冰箱", "interaction": "fridge", "desc": "从冰箱拿取食物（可先直接吃，或去厨具加热）。该交互不加好感度。", "size": Vector2i(1, 1), "pos": Vector2i(0, 10), "color": Color(0.75, 0.85, 0.92)},
	{"id": "kitchen", "name": "厨具", "interaction": "cook", "desc": "把冰箱拿到的食物做成熟饭（熟饭吃得更多、心情更好）。该交互不加好感度。", "size": Vector2i(2, 1), "pos": Vector2i(7, 10), "color": Color(0.62, 0.50, 0.42)},
	{"id": "dining", "name": "饭桌", "interaction": "eat", "desc": "有食物时坐下来吃：生食吃得少，熟食吃得饱、心情更好；也可在沙发上吃。该交互不加好感度。", "size": Vector2i(2, 1), "pos": Vector2i(8, 8), "color": Color(0.72, 0.55, 0.38)},
]

var _target_cell: Vector2i = Vector2i(-1, -1)
var _computer_panel: Control = null
var _settings_overlay: Control = null
var _layout_overlay: Control = null
var _help_overlay: Control = null
var _pending_guide := false
var _pending_trigger_interaction := ""
var _blocked_cells: Dictionary = {}
var _furniture_list: Array = []
var _layout_objects: Array = []
var _phone_overlay: Control = null
var _bubble: Control = null
var _notify_fx: Control = null
var _toast: Control = null
var _notify_player: AudioStreamPlayer = null
var _attract_seq := 0
var _attract_item: Dictionary = {}   # {"spec": Dictionary, "cell": Vector2i}
var _attract_item_bob := 0.0
var _idle_since := 0.0               # 距上次玩家输入（秒）
var _autonomy_active := false
var _autonomy_task: Dictionary = {}  # {"type": String, ...}
var _autonomy_wait := 0.0            # 两次自主动作之间的等待
var _autonomy_elapsed := 0.0
var _autonomy_playing_computer := false
var _last_autonomy_type := ""
var _interaction_specs: Dictionary = {}
var _interaction_menu: Panel = null
var _interaction_running := false

@onready var character: CharacterBody2D = $Room/Character
@onready var status_label: Label = $UI/StatusLabel
@onready var play_together_button: Button = $UI/PlayTogetherButton
@onready var portrait_manager = $UI/PortraitLayer/PortraitTexture


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
	$UI/PhoneButton.pressed.connect(_on_phone_pressed)

	_phone_overlay = PHONE_OVERLAY_SCENE.instantiate()
	$UI.add_child(_phone_overlay)
	_phone_overlay.closed.connect(_on_phone_overlay_closed)
	_phone_overlay.reaction.connect(_on_phone_reaction)
	_phone_overlay.action_requested.connect(_on_phone_action)
	_phone_overlay.notification_triggered.connect(_on_phone_notification)
	_phone_overlay.player_activity.connect(_mark_player_activity)
	play_together_button.pressed.connect(_on_play_together_pressed)
	_interaction_specs = CharacterInteractions.load_specs(GameManager.CURRENT_CHAR_ID)
	_build_interaction_menu()

	_bubble = BUBBLE_SCENE.instantiate()
	$UI.add_child(_bubble)

	_notify_fx = NOTIFY_FX_SCENE.instantiate()
	$UI.add_child(_notify_fx)

	_toast = TOAST_SCENE.instantiate()
	$UI.add_child(_toast)

	_notify_player = AudioStreamPlayer.new()
	_notify_player.stream = load(NOTIFY_SOUND_PATH)
	add_child(_notify_player)

	_setup_offline_settlement()

	status_label.text = "温馨小屋：点击地板移动，F11 切换全屏"
	queue_redraw()

	# 首次进入：自动弹出新手攻略
	if not ConfigManager.get_value("general", "guide_seen", false):
		_open_help_overlay("guide")

	# 启动后自动演示一次：走向书桌旁边的空地
	await get_tree().create_timer(0.6).timeout
	_target_cell = Vector2i(5, 6)
	character.move_to_cell(_target_cell)


func _process(delta: float) -> void:
	_attract_item_bob += delta * 2.4
	_status_tick(delta)
	queue_redraw()


func _status_tick(delta: float) -> void:
	StatusManager.tick_online(delta)
	_idle_since += delta
	_autonomy_tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		_mark_player_activity()
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
			if cell == character.current_cell:
				# 点击角色：打开/关闭数据驱动互动菜单
				if _interaction_menu != null and _interaction_menu.visible:
					_close_interaction_menu()
				else:
					_open_character_interaction_menu()
				return
			if _interaction_menu != null and _interaction_menu.visible:
				_close_interaction_menu()
			var furniture := _get_furniture_at(cell)
			if not furniture.is_empty():
				_handle_furniture_click(furniture)
				return
			_attract_to_cell(cell)


func _on_main_settings_pressed() -> void:
	_mark_player_activity()
	if _settings_overlay != null:
		_settings_overlay.open_overlay()


func _on_settings_overlay_closed() -> void:
	status_label.text = "设置已关闭"


func _on_furniture_help_pressed() -> void:
	_mark_player_activity()
	_open_help_overlay("furniture")


## ---------------- P0 手机消息 ----------------


func _on_phone_pressed() -> void:
	if _computer_panel.visible or _settings_overlay.visible or _help_overlay != null and _help_overlay.visible:
		return
	if _layout_overlay != null and _layout_overlay.visible:
		return
	_mark_player_activity()
	if _phone_overlay != null:
		_phone_overlay.open_overlay()


func _on_phone_overlay_closed() -> void:
	status_label.text = "手机已收起"


func _on_phone_reaction(text: String, emotion: String) -> void:
	_play_notify_sound()
	if _bubble != null:
		_bubble.position = character.position + Vector2(4.0, -54.0)
		_bubble.show_bubble(text, 3.0)
	# 情绪 → 立绘差分（临时表情）
	match emotion:
		"happy", "praise":
			portrait_manager.set_expression("happy", 2.5)
		"shy":
			portrait_manager.set_expression("shy", 2.5)
		"surprised":
			portrait_manager.set_expression("surprised", 2.5)
		"sad":
			portrait_manager.set_expression("low", 2.5)


func _on_phone_notification() -> void:
	## 角色“收到”手机消息：提示音 + 头顶特效 + 顶部通知横幅
	_play_notify_sound()
	if _notify_fx != null:
		_notify_fx.position = character.position + Vector2(-2.0, -60.0)
		_notify_fx.play_effect()
	if _toast != null:
		_toast.position = Vector2(292.0, 42.0)
		_toast.show_toast()
	status_label.text = "梅尔收到了新消息！"
	portrait_manager.set_expression("surprised", 1.5)


func _on_phone_action(action_name: String) -> void:
	var interactions := ["sleep", "read", "sit", "watch", "rest", "light", "water", "computer"]
	if action_name in interactions:
		_move_to_furniture_and_trigger(action_name)
		return
	match action_name:
		"wave", "hop", "sad":
			character.stop_movement()
			character.play_action(action_name)
		_:
			character.stop_movement()
			character.play_action("wave")


func _play_notify_sound() -> void:
	if _notify_player != null and _notify_player.stream != null:
		_notify_player.play()


func _move_to_furniture_and_trigger(interaction_name: String) -> void:
	var entry := {}
	for furniture in _furniture_list:
		if str(furniture["interaction"]) == interaction_name:
			entry = furniture
			break
	if entry.is_empty():
		return
	if _is_adjacent_to_furniture(character.current_cell, entry["cells"]):
		character.trigger_interaction(interaction_name)
		return
	var target := _find_nearest_free_cell_near_furniture(entry["cells"])
	if target.x < 0:
		status_label.text = "手机指令：%s 附近没有可站立位置" % interaction_name
		return
	if target == character.current_cell:
		character.trigger_interaction(interaction_name)
		return
	_pending_trigger_interaction = interaction_name
	_target_cell = target
	character.move_to_cell(target)
	status_label.text = "手机指令：走向 %s" % interaction_name


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
	if interaction_name == "computer":
		_open_computer_panel()
		return
	if interaction_name == "decorate":
		# 布置台：弹出自定义界面；不加好感度（与其它家具交互不同）
		_open_layout_overlay()
		return
	# 数据驱动互动（角色文件）：按 entry 匹配家具交互，优先于通用注册
	for key in _interaction_specs:
		var spec: Dictionary = _interaction_specs[key]
		if str(spec.get("entry", "")) == "furniture:" + interaction_name:
			_run_interaction(key)
			return
	# 看完电视后短暂开心（立绘差分；看书由角色文件互动处理）
	if interaction_name == "watch":
		portrait_manager.set_expression("happy", 8.0)
	match interaction_name:
		"fridge":
			_take_food()
			return
		"cook":
			_cook_food()
			return
		"eat":
			_eat_food()
			return
		"rest":
			# 沙发：有食物时吃东西（与饭桌一致），否则按休息处理
			if StatusManager.get_food() != "none":
				_eat_food()
				return
	MemoryManager.record_daily_event(char_id, "interaction", interaction_name)
	var added := GameManager.register_interaction(char_id, interaction_name)
	if added:
		status_label.text = "触发交互：%s（好感 +1）" % interaction_name
	else:
		status_label.text = "触发交互：%s" % interaction_name


## ---------------- P2 进食链路 ----------------

func _take_food() -> void:
	StatusManager.set_food("raw")
	MemoryManager.record_daily_event(GameManager.CURRENT_CHAR_ID, "interaction", "fridge")
	status_label.text = "从冰箱拿出了食物，可以直接吃，或去厨具加热"


func _cook_food() -> void:
	var food := StatusManager.get_food()
	if food == "none":
		status_label.text = "厨具空空的，先去冰箱拿点食物吧"
		return
	StatusManager.set_food("cooked")
	StatusManager.apply_delta(0, 1, 0)
	MemoryManager.record_daily_event(GameManager.CURRENT_CHAR_ID, "interaction", "cook")
	status_label.text = "做好饭啦！去饭桌（或沙发）吃吧（心情 +1）"


func _eat_food() -> void:
	var food := StatusManager.get_food()
	if food == "none":
		status_label.text = "还没有食物，去冰箱看看吧"
		return
	if food == "raw":
		StatusManager.apply_delta(20, 0, 3)
		status_label.text = "吃了一点生食（饱食 +20）"
	else:
		StatusManager.apply_delta(35, 2, 2)
		status_label.text = "吃了一顿好饭（饱食 +35，心情 +2）"
	StatusManager.set_food("none")
	MemoryManager.record_daily_event(GameManager.CURRENT_CHAR_ID, "interaction", "eat")


func _open_computer_panel() -> void:
	if _computer_panel != null:
		_computer_panel.open_panel()


func _on_computer_panel_closed() -> void:
	status_label.text = "电脑桌已关闭"


func _handle_furniture_click(furniture: Dictionary) -> void:
	_attract_to_furniture(furniture)


## ---------------- P3 其他互动（角色文件数据驱动） ----------------

func _build_interaction_menu() -> void:
	var panel := Panel.new()
	panel.size = Vector2(190, 42 + (4) * 34)  # 上限：角色入口最多显示 3 项 + 标题 + 关闭
	panel.position = Vector2(150, 84)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 30
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.text = "想和梅尔做什么？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for id in _interaction_specs.keys():
		var spec: Dictionary = _interaction_specs[id]
		if str(spec.get("entry", "")) != "character":
			continue
		var btn := Button.new()
		btn.text = str(spec.get("name", id))
		btn.pressed.connect(_on_interaction_menu_choice.bind(id))
		box.add_child(btn)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(_close_interaction_menu)
	box.add_child(close)
	$UI.add_child(panel)
	_interaction_menu = panel


func _open_character_interaction_menu() -> void:
	_mark_player_activity()
	if _interaction_menu != null:
		_interaction_menu.visible = true
		status_label.text = "想做点什么？"


func _close_interaction_menu() -> void:
	if _interaction_menu != null:
		_interaction_menu.visible = false


func _on_interaction_menu_choice(spec_id: String) -> void:
	_close_interaction_menu()
	_run_interaction(spec_id)


## 执行角色文件中的互动：上限检查 → 效果/好感 → 动作/表情 → 台词气泡。
func _run_interaction(spec_id: String) -> void:
	if _interaction_running:
		return
	var spec: Dictionary = _interaction_specs.get(spec_id, {})
	if spec.is_empty():
		return
	var char_id := GameManager.CURRENT_CHAR_ID

	# 上限检查（每日次数 / 冷却）
	var limits: Dictionary = spec.get("limits", {})
	var usage := GameManager.get_interaction_usage(char_id, spec_id)
	if limits.has("daily"):
		var date := str(usage.get("date", ""))
		var count := int(usage.get("count", 0))
		if date == GameManager.today() and count >= int(limits["daily"]):
			status_label.text = "今天已经 %d 次啦，改天吧" % count
			return
	if limits.has("cooldown"):
		var last := float(usage.get("last", 0.0))
		var cd := float(limits["cooldown"])
		var elapsed := Time.get_unix_time_from_system() - last
		if last > 0.0 and elapsed < cd:
			status_label.text = "刚玩过，等 %d 秒吧" % int(cd - elapsed)
			return
	GameManager.record_interaction_usage(char_id, spec_id)
	_interaction_running = true

	# 状态效果
	var effects: Dictionary = spec.get("effects", {})
	StatusManager.apply_delta(
		int(effects.get("satiety", 0)),
		int(effects.get("mood", 0)),
		int(effects.get("fatigue", 0))
	)

	# 好感
	var aff_text := ""
	var aff: Dictionary = spec.get("affection", {})
	var aff_amount := int(aff.get("amount", 0))
	if aff_amount > 0:
		var applied := GameManager.add_affection(
			char_id, aff_amount, str(aff.get("reason", spec_id)), "interaction"
		)
		if applied > 0:
			aff_text = "（好感 +%d）" % applied

	# 记录日记
	MemoryManager.record_daily_event(char_id, "interaction", spec_id)

	# 动作与立绘
	for action in spec.get("actions", []):
		character.play_action(str(action))
	var expression := str(spec.get("expression", ""))
	if not expression.is_empty():
		portrait_manager.set_expression(expression, float(spec.get("expression_duration", 2.0)))

	# 台词气泡（延迟一小会再说话）
	var reply_delay := float(spec.get("reply_delay", 0.6))
	if reply_delay > 0.0:
		await get_tree().create_timer(reply_delay).timeout
	var texts: Array = spec.get("texts", [])
	if not texts.is_empty():
		_bubble_show(str(texts[randi_range(0, texts.size() - 1)]), 3.0)

	status_label.text = "%s %s" % [str(spec.get("name", spec_id)), aff_text]
	_interaction_running = false


## ---------------- P1 吸引移动（点击引导 + 主动靠近） ----------------

const ATTRACT_AFTER_DELAY := 0.4   # 反应动作后出发的停顿
const ATTRACT_AFFECT_CHANCE_HIGH := 0.9
const ATTRACT_AFFECT_CHANCE_DEFAULT := 0.75


func _attract_to_cell(cell: Vector2i) -> void:
	if not _inside_grid(cell):
		return
	_attract_seq += 1
	var seq := _attract_seq
	_cancel_pending_trigger()
	character.stop_movement()
	_target_cell = cell
	_set_attract_item(cell)
	_show_attract_notice(true)
	if not _will_respond():
		_clear_attract_item()
		_show_distract_fx()
		status_label.text = "梅尔似乎没注意到…"
		return
	character.play_action("hop")
	status_label.text = "梅尔被吸引了…"
	await get_tree().create_timer(ATTRACT_AFTER_DELAY).timeout
	if seq != _attract_seq:
		return
	if cell == character.current_cell:
		_clear_attract_item()
		return
	character.move_to_cell(cell)


func _attract_to_furniture(furniture: Dictionary) -> void:
	_attract_seq += 1
	var seq := _attract_seq
	_cancel_pending_trigger()
	character.stop_movement()
	var target := _find_nearest_free_cell_near_furniture(furniture["cells"])
	if target.x < 0:
		_show_attract_notice(true)
		status_label.text = "附近没有可站立的位置"
		return
	_target_cell = target
	_set_attract_item(target)
	_show_attract_notice(true)
	if not _will_respond():
		_clear_attract_item()
		_show_distract_fx()
		status_label.text = "梅尔似乎没注意到…"
		return
	character.play_action("hop")
	status_label.text = "梅尔被%s吸引了…" % furniture["type"]
	await get_tree().create_timer(ATTRACT_AFTER_DELAY).timeout
	if seq != _attract_seq:
		return
	if _is_adjacent_to_furniture(character.current_cell, furniture["cells"]):
		_clear_attract_item()
		character.trigger_interaction(furniture["interaction"])
		return
	_pending_trigger_interaction = furniture["interaction"]
	character.move_to_cell(target)


func _will_respond() -> bool:
	## 好感度影响“被吸引”意愿：≥70 必应；≥50 90%；其余 75%。
	var affection := GameManager.get_affection(GameManager.CURRENT_CHAR_ID)
	var chance := ATTRACT_AFFECT_CHANCE_DEFAULT
	if affection >= 70:
		chance = 1.0
	elif affection >= 50:
		chance = ATTRACT_AFFECT_CHANCE_HIGH
	return randf() <= chance


func _show_attract_notice(_respond: bool) -> void:
	if _notify_fx != null:
		_notify_fx.position = character.position + Vector2(-2.0, -60.0)
		_notify_fx.play_effect(0.9)


func _show_distract_fx() -> void:
	## 走神：与「！」同款头顶特效，仅符号换成「？」并停留更久。
	if _notify_fx != null:
		_notify_fx.position = character.position + Vector2(-2.0, -60.0)
		_notify_fx.play_effect(1.4, "？")
	portrait_manager.set_expression("distracted", 2.5)


func _cancel_pending_trigger() -> void:
	_pending_trigger_interaction = ""


## ---------------- P2 自主行为（现实时间 / 状态驱动） ----------------

const AUTONOMY_IDLE_DELAY := 8.0
const AUTONOMY_PAUSE_MIN := 1.2
const AUTONOMY_PAUSE_MAX := 3.0

const WINDOW_CELLS := [Vector2i(0, 6), Vector2i(1, 6), Vector2i(0, 7), Vector2i(1, 7)]


func _mark_player_activity() -> void:
	## 任何玩家输入：重置空闲计时；正在自主则打断（电脑「一起玩」按钮点击除外，见按钮处理）。
	_idle_since = 0.0
	if _autonomy_active:
		_stop_autonomy()


func _can_autonomy_start() -> bool:
	if _computer_panel.visible:
		return false
	if _settings_overlay.visible:
		return false
	if _help_overlay != null and _help_overlay.visible:
		return false
	if _layout_overlay != null and _layout_overlay.visible:
		return false
	return true


func _autonomy_tick(delta: float) -> void:
	if not _autonomy_active:
		if _idle_since >= AUTONOMY_IDLE_DELAY and _can_autonomy_start():
			_start_autonomy()
		return
	if not _autonomy_task.is_empty() and str(_autonomy_task.get("type", "")) == "computer_play" \
			and str(_autonomy_task.get("phase", "")) == "playing":
		var task: Dictionary = _autonomy_task
		task["time_left"] = float(task["time_left"]) - delta
		_autonomy_task = task
		if float(task["time_left"]) <= 0.0:
			_autonomy_playing_computer = false
			_set_play_together_visible(false)
			_autonomy_task = {}
			_autonomy_wait = randf_range(2.0, 4.0)
		return
	if _autonomy_task.is_empty():
		if _autonomy_wait > 0.0:
			_autonomy_wait -= delta
			if _autonomy_wait <= 0.0:
				_begin_autonomy_task(_pick_autonomy_task())
		else:
			_begin_autonomy_task(_pick_autonomy_task())


func _start_autonomy() -> void:
	_autonomy_active = true
	_autonomy_elapsed = 0.0
	_autonomy_task = {}
	_autonomy_wait = randf_range(1.5, 3.0)
	status_label.text = "梅尔开始自己活动了…"


func _stop_autonomy(_interrupt: bool = true) -> void:
	_autonomy_active = false
	_autonomy_task = {}
	_autonomy_wait = 0.0
	_autonomy_playing_computer = false
	_set_play_together_visible(false)


func _pick_autonomy_task() -> Dictionary:
	var satiety := StatusManager.get_satiety()
	var fatigue := StatusManager.get_fatigue()
	var mood := StatusManager.get_mood()
	var hour := int(Time.get_time_dict_from_system()["hour"])
	var night := hour >= 22 or hour < 6

	if satiety < 45:
		return {"type": "eat"}
	if night:
		if fatigue > 30:
			return {"type": "rest"}
		return {"type": "window"} if mood < 50 else {"type": "wander"}
	if fatigue > 60:
		return {"type": "rest"}
	if mood < 35:
		return {"type": "window"}

	var pool: Array = [
		{"type": "wander"},
		{"type": "wander"},
		{"type": "furniture", "interaction": "read"},
		{"type": "furniture", "interaction": "watch"},
		{"type": "furniture", "interaction": "sit"},
		{"type": "furniture", "interaction": "light"},
		{"type": "furniture", "interaction": "water"},
	]
	if satiety < 65:
		pool.append({"type": "eat"})
	if randf() < 0.25:
		pool.append({"type": "computer_play"})
	var task: Dictionary = pool[randi() % pool.size()]
	if str(task["type"]) == _last_autonomy_type and pool.size() > 1:
		task = pool[(pool.find(task) + 1) % pool.size()]
	return task


func _begin_autonomy_task(task: Dictionary) -> void:
	_last_autonomy_type = str(task["type"])
	match str(task["type"]):
		"wander":
			_autonomy_task = task
			_autonomy_move_to_target(_random_free_cell())
		"window":
			_autonomy_task = task
			_autonomy_move_to_target(_pick_window_cell())
		"furniture":
			_autonomy_task = task
			if not _autonomy_go_furniture(str(task["interaction"])):
				_autonomy_task = {}
				_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN, AUTONOMY_PAUSE_MAX)
		"eat":
			_autonomy_task = {"type": "eat", "phase": "fridge"}
			if not _autonomy_go_furniture("fridge"):
				_autonomy_task = {}
				_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN, AUTONOMY_PAUSE_MAX)
		"rest":
			var interaction := "sleep" if StatusManager.get_fatigue() > 75 else "rest"
			_autonomy_task = {"type": "rest", "interaction": interaction}
			if not _autonomy_go_furniture(interaction):
				_autonomy_task = {}
				_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN, AUTONOMY_PAUSE_MAX)
		"computer_play":
			_autonomy_task = {"type": "computer_play", "phase": "to_desk"}
			if not _autonomy_go_furniture("computer"):
				_autonomy_task = {}
				_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN, AUTONOMY_PAUSE_MAX)


func _autonomy_move_to_target(target: Vector2i) -> void:
	if target == character.current_cell:
		_autonomy_arrived()
		return
	_target_cell = target
	character.move_to_cell(target)


func _autonomy_go_furniture(interaction: String) -> bool:
	var entry := _find_furniture_by_interaction(interaction)
	if entry.is_empty():
		return false
	var target := _find_nearest_free_cell_near_furniture(entry["cells"])
	if target.x < 0:
		return false
	_autonomy_move_to_target(target)
	return true


func _autonomy_arrived() -> void:
	if not _autonomy_active or _autonomy_task.is_empty():
		return
	var task: Dictionary = _autonomy_task
	match str(task["type"]):
		"wander", "window":
			if str(task["type"]) == "window":
				_bubble_show("（望着窗外发呆…）", 2.2)
				StatusManager.apply_delta(0, 1, 0)
				MemoryManager.record_daily_event(GameManager.CURRENT_CHAR_ID, "autonomy", "在窗边发呆")
			_autonomy_task = {}
			_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN, AUTONOMY_PAUSE_MAX)
		"furniture":
			_autonomy_do_furniture(str(task["interaction"]))
		"rest":
			_autonomy_do_rest(str(task.get("interaction", "rest")))
		"eat":
			_autonomy_eat_arrived(task)
		"computer_play":
			_autonomy_playing_computer = true
			_set_play_together_visible(true)
			task["phase"] = "playing"
			task["time_left"] = randf_range(18.0, 32.0)
			_autonomy_task = task
			StatusManager.apply_delta(0, 2, 2)
			_autonomy_diary("在电脑前玩了会儿")
			_autonomy_maybe_gain()


func _autonomy_do_furniture(interaction: String) -> void:
	match interaction:
		"read":
			_bubble_show("（看了会儿书…）", 2.2)
			StatusManager.apply_delta(0, 2, 1)
		"watch":
			_bubble_show("（津津有味地看电视…）", 2.2)
			StatusManager.apply_delta(0, 2, 2)
		"sit":
			_bubble_show("（安安静静坐了一会儿…）", 2.2)
			StatusManager.apply_delta(0, 1, 0)
		"light":
			_bubble_show("（开着灯看书…）", 2.2)
			StatusManager.apply_delta(0, 1, 1)
		"water":
			_bubble_show("（给盆栽浇水…）", 2.2)
			StatusManager.apply_delta(0, 1, 0)
		_:
			_bubble_show("（无所事事…）", 2.0)
	_autonomy_diary("使用了「%s」" % interaction)
	_autonomy_maybe_gain()
	_autonomy_task = {}
	_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN, AUTONOMY_PAUSE_MAX)


func _autonomy_do_rest(interaction: String) -> void:
	if interaction == "sleep":
		StatusManager.apply_delta(0, 2, -30)
		_bubble_show("（好累，睡一小会儿…）", 2.5)
		_autonomy_diary("去床上休息")
		_autonomy_maybe_gain()
	else:
		StatusManager.apply_delta(0, 1, -20)
		_bubble_show("（在沙发上瘫了一会儿…）", 2.5)
		_autonomy_diary("在沙发休息")
		_autonomy_maybe_gain()
	_autonomy_task = {}
	_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN + 2.0, AUTONOMY_PAUSE_MAX + 3.0)


func _autonomy_eat_arrived(task: Dictionary) -> void:
	match str(task["phase"]):
		"fridge":
			_take_food()
			if StatusManager.get_satiety() < 35:
				task["phase"] = "kitchen"
			else:
				task["phase"] = "dining"
			_autonomy_task = task
			var next_interaction := "cook" if str(task["phase"]) == "kitchen" else "eat"
			if not _autonomy_go_furniture(next_interaction):
				# 找不到位置就直接吃
				_autonomy_task = {}
				_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN, AUTONOMY_PAUSE_MAX)
		"kitchen":
			_cook_food()
			task["phase"] = "dining"
			_autonomy_task = task
			if not _autonomy_go_furniture("eat"):
				_autonomy_task = {}
				_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN, AUTONOMY_PAUSE_MAX)
		"dining":
			_eat_food()
			_autonomy_diary("吃东西")
			_autonomy_maybe_gain()
			_autonomy_task = {}
			_autonomy_wait = randf_range(AUTONOMY_PAUSE_MIN + 1.0, AUTONOMY_PAUSE_MAX + 2.0)


func _autonomy_maybe_gain() -> void:
	## 正式自主行为完成：50% 概率 +1，日上限 +3（StatusManager 内校验）。
	if StatusManager.try_autonomy_affection(1):
		var applied := GameManager.add_affection(
			GameManager.CURRENT_CHAR_ID, 1, "自主行为", "autonomy"
		)
		if applied > 0:
			_bubble_show("（+1 好感：自主行为）", 1.6)


func _autonomy_diary(detail: String) -> void:
	MemoryManager.record_daily_event(GameManager.CURRENT_CHAR_ID, "autonomy", detail)


func _pick_window_cell() -> Vector2i:
	for cell in WINDOW_CELLS.duplicate():
		if not _blocked_cells.has(cell):
			return cell
	return _random_free_cell()


func _random_free_cell() -> Vector2i:
	for _i in range(40):
		var cell := Vector2i(randi() % GRID_SIZE.x, randi() % GRID_SIZE.y)
		if not _blocked_cells.has(cell):
			return cell
	return character.current_cell


func _find_furniture_by_interaction(interaction: String) -> Dictionary:
	for furniture in _furniture_list:
		if str(furniture["interaction"]) == interaction:
			return furniture
	return {}


func _set_play_together_visible(visible: bool) -> void:
	if play_together_button != null:
		play_together_button.visible = visible


func _on_play_together_pressed() -> void:
	## 角色自主用电脑时玩家加入：直接打开电脑并进入游戏选择。
	if _computer_panel != null:
		_computer_panel.open_panel()
		_computer_panel.open_game_select()
	_autonomy_playing_computer = false
	_set_play_together_visible(false)
	_autonomy_active = false
	_autonomy_task = {}
	status_label.text = "和梅尔一起玩游戏吧！"


func _bubble_show(text: String, duration: float = 3.0) -> void:
	if _bubble != null:
		_bubble.position = character.position + Vector2(4.0, -54.0)
		_bubble.show_bubble(text, duration)


## ---------------- P2 离线结算（现实时间模拟 + AI 情绪） ----------------

const OFFLINE_MIN_SECONDS := 1800.0


func _setup_offline_settlement() -> void:
	var speed := maxf(float(ConfigManager.get_value("general", "dev_state_speed", 1)), 1.0)
	var threshold := OFFLINE_MIN_SECONDS / speed
	var offline := StatusManager.get_offline_seconds()
	if offline >= threshold:
		StatusManager.apply_offline_seconds(offline)
		StatusManager.mark_seen()
		_run_offline_ai_settlement(offline)
	else:
		StatusManager.mark_seen()


func _run_offline_ai_settlement(seconds: float) -> void:
	var char_id := GameManager.CURRENT_CHAR_ID
	var persona := MemoryManager.get_persona_system(char_id)
	var context: Array = MemoryManager.build_chat_context(char_id, persona)
	var hours := int(seconds / 3600.0)
	var mins := int(seconds / 60.0) % 60
	var instruction := (
		"主人在过去约%d小时%d分钟后回来陪你了（你独自生活了这么久）。"
		+ "请以梅尔的身份，结合人设、记忆和当前状态：%s。\n只输出一个 JSON 对象（不要其他文字、不要 Markdown 代码块）："
		+ "{\"satiety\":-10,\"fatigue\":10,\"mood\":5,\"affection\":0或1,\"message\":\"20字以内想对主人说的话\"}。\n"
		+ "说明：satiety/fatigue 的自然变化已按离线时长先算过一次，这里输出这段经历带来的额外修正（整数，-10~+10）；"
		+ "mood 由独立生活的经历决定（整数，-15~+15）；affection=1 表示因为想念主人而好感+1（当天好感最多+3）。"
	) % [hours, mins, StatusManager.get_state_summary()]
	context.append({"role": "user", "content": instruction})
	AIConnector.request_json(context, _on_offline_settled, _on_offline_settle_error)


func _on_offline_settled(data: Dictionary) -> void:
	StatusManager.apply_delta(
		_clamp_val(data.get("satiety"), 0, -10, 10),
		_clamp_val(data.get("mood"), 0, -15, 15),
		_clamp_val(data.get("fatigue"), 0, -10, 10)
	)
	var message := str(data.get("message", "你回来啦…")).strip_edges()
	if message.is_empty():
		message = "你回来啦…"
	_bubble_show(message, 4.0)
	MemoryManager.record_daily_event(GameManager.CURRENT_CHAR_ID, "autonomy", "离线归来：" + message)
	var affection := _as_bool(data.get("affection", false))
	if affection and StatusManager.add_autonomy_affection(1):
		var applied := GameManager.add_affection(GameManager.CURRENT_CHAR_ID, 1, "离线想念", "offline")
		if applied > 0:
			status_label.text = "梅尔略带想念地望着你（好感 +1）"
			return
	status_label.text = "梅尔回来见你啦"


func _on_offline_settle_error(_message: String) -> void:
	_bubble_show("你不在的时候，梅尔过得安静又平淡…", 3.5)
	status_label.text = "离线期间梅尔独自生活（结算失败，已按时间自动计算）"


func _clamp_val(value, default: int, lo: int, hi: int) -> int:
	var v := default
	if value is int or value is float:
		v = int(value)
	elif value is String and (value as String).is_valid_int():
		v = int(value)
	return clampi(v, lo, hi)


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return int(value) != 0
	if value is String:
		var s := (value as String).strip_edges().to_lower()
		return s in ["true", "yes", "是", "y", "1", "对", "想念"]
	return false


func _as_int(value, default: int) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and (value as String).is_valid_int():
		return int(value)
	return default


func _set_attract_item(cell: Vector2i) -> void:
	## 按设置选择吸引物：random 或固定 id；放置在点击位置。
	var mode := str(ConfigManager.get_value("general", "attract_item", ATTRACT_ITEM_DEFAULT))
	var spec: Dictionary = {}
	if mode == "random":
		spec = ATTRACT_ITEMS[randi() % ATTRACT_ITEMS.size()]
	else:
		for item in ATTRACT_ITEMS:
			if str(item["id"]) == mode:
				spec = item
				break
	if spec.is_empty():
		spec = ATTRACT_ITEMS[0]
	_attract_item = {"spec": spec, "cell": cell}
	queue_redraw()


func _clear_attract_item() -> void:
	if _attract_item.is_empty():
		return
	_attract_item = {}
	queue_redraw()


func _on_attract_arrived() -> void:
	## 角色到达吸引物所在格：物品消失。
	if _attract_item.is_empty():
		return
	var item_cell: Vector2i = _attract_item.get("cell", Vector2i(-1, -1))
	if item_cell == character.current_cell:
		_clear_attract_item()


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
	_draw_attract_item()


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
	_draw_fridge()
	_draw_kitchen()
	_draw_dining()
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


func _draw_fridge() -> void:
	var f := _cell_rect(_furniture_pos("fridge"), Vector2i(1, 1))
	# 冰箱主体（浅蓝）
	draw_rect(Rect2(f.position + Vector2(2, 1), Vector2(12, 13)), Color(0.80, 0.88, 0.95))
	# 上下门缝
	draw_line(f.position + Vector2(2, 8), f.position + Vector2(14, 8), Color(0.52, 0.62, 0.72), 1.0)
	# 把手
	draw_rect(Rect2(f.position + Vector2(10, 2), Vector2(2, 4)), Color(0.52, 0.62, 0.72))
	draw_rect(Rect2(f.position + Vector2(10, 9), Vector2(2, 4)), Color(0.52, 0.62, 0.72))
	# 底脚
	draw_rect(Rect2(f.position + Vector2(3, 14), Vector2(2, 1)), Color(0.45, 0.55, 0.62))
	draw_rect(Rect2(f.position + Vector2(11, 14), Vector2(2, 1)), Color(0.45, 0.55, 0.62))


func _draw_kitchen() -> void:
	var k := _cell_rect(_furniture_pos("kitchen"), Vector2i(2, 1))
	# 台面
	draw_rect(Rect2(k.position + Vector2(2, 6), Vector2(28, 8)), Color(0.48, 0.38, 0.32))
	# 两块面板
	draw_rect(Rect2(k.position + Vector2(4, 3), Vector2(10, 9)), Color(0.36, 0.28, 0.24))
	draw_rect(Rect2(k.position + Vector2(18, 3), Vector2(10, 9)), Color(0.36, 0.28, 0.24))
	# 灶眼
	draw_circle(k.position + Vector2(9, 7.5), 2.4, Color(0.18, 0.14, 0.12))
	draw_circle(k.position + Vector2(23, 7.5), 2.4, Color(0.18, 0.14, 0.12))
	# 锅具
	draw_rect(Rect2(k.position + Vector2(7, 5), Vector2(5, 3)), Color(0.55, 0.55, 0.60))


func _draw_dining() -> void:
	var d := _cell_rect(_furniture_pos("dining"), Vector2i(2, 1))
	# 桌面
	draw_rect(Rect2(d.position + Vector2(2, 8), Vector2(28, 5)), Color(0.72, 0.55, 0.38))
	# 桌沿高光
	draw_rect(Rect2(d.position + Vector2(2, 8), Vector2(28, 1)), Color(0.85, 0.68, 0.48))
	# 桌腿
	draw_rect(Rect2(d.position + Vector2(4, 13), Vector2(2, 2)), Color(0.48, 0.34, 0.24))
	draw_rect(Rect2(d.position + Vector2(26, 13), Vector2(2, 2)), Color(0.48, 0.34, 0.24))
	# 桌上小碗
	draw_rect(Rect2(d.position + Vector2(13, 7), Vector2(6, 2)), Color(0.95, 0.82, 0.60))


func _draw_plant() -> void:
	var plant := _cell_rect(_furniture_pos("plant"), Vector2i(1, 1))	# 叶子
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


func _draw_attract_item() -> void:
	if _attract_item.is_empty():
		return
	var spec: Dictionary = _attract_item["spec"]
	var cell: Vector2i = _attract_item["cell"]
	var center := _cell_center(cell) + Vector2(0.0, sin(_attract_item_bob) * 2.0)
	var kind := str(spec["id"])
	# 柔光底
	draw_circle(center, 9.0, Color(1.0, 0.92, 0.65, 0.18))
	match kind:
		"heart":
			draw_circle(center + Vector2(-3, -2), 3.0, Color(0.95, 0.45, 0.55))
			draw_circle(center + Vector2(3, -2), 3.0, Color(0.95, 0.45, 0.55))
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-5.5, -1),
				center + Vector2(5.5, -1),
				center + Vector2(0, 6),
			]), Color(0.95, 0.45, 0.55))
		"fish":
			draw_circle(center + Vector2(-1, 0), 4.0, Color(0.55, 0.75, 0.95))
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(2.5, -3.5),
				center + Vector2(6, 0),
				center + Vector2(2.5, 3.5),
			]), Color(0.55, 0.75, 0.95))
			draw_circle(center + Vector2(-3.5, -1.5), 0.8, Color(0.15, 0.2, 0.3))
		"apple":
			draw_circle(center + Vector2(0, 1), 4.5, Color(0.88, 0.36, 0.30))
			draw_rect(Rect2(center + Vector2(-0.8, -6.0), Vector2(1.6, 2.5)), Color(0.42, 0.28, 0.18))
			draw_rect(Rect2(center + Vector2(0.6, -6.2), Vector2(3.2, 1.6)), Color(0.45, 0.70, 0.35))
		"star":
			var pts := PackedVector2Array()
			for i in range(10):
				var angle := -PI / 2.0 + i * PI / 5.0
				var r := 6.0 if i % 2 == 0 else 2.6
				pts.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(pts, Color(1.0, 0.85, 0.35))
		"ball":
			draw_circle(center, 4.5, Color(0.85, 0.55, 0.70))
			draw_arc(center, 4.5, 0.6, 2.4, 12, Color(1.0, 0.9, 0.9), 1.4)
			draw_circle(center + Vector2(-1.4, -1.6), 1.1, Color(1.0, 0.95, 0.95))
		"book":
			draw_rect(Rect2(center + Vector2(-5, -5), Vector2(10, 10)), Color(0.92, 0.80, 0.58))
			draw_rect(Rect2(center + Vector2(-5, -5), Vector2(2.5, 10)), Color(0.70, 0.50, 0.32))
			draw_rect(Rect2(center + Vector2(-1, -4), Vector2(5, 1.2)), Color(0.50, 0.38, 0.25))
			draw_rect(Rect2(center + Vector2(-1, -1.8), Vector2(5, 1.2)), Color(0.50, 0.38, 0.25))
			draw_rect(Rect2(center + Vector2(-1, 0.4), Vector2(5, 1.2)), Color(0.50, 0.38, 0.25))


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
		return
	if _autonomy_active and not _autonomy_task.is_empty():
		_autonomy_arrived()
		return
	_on_attract_arrived()
	if _pending_trigger_interaction != "":
		var interaction_name := _pending_trigger_interaction
		_pending_trigger_interaction = ""
		_target_cell = Vector2i(-1, -1)
		character.trigger_interaction(interaction_name)
		return
	status_label.text = "角色已到达"
