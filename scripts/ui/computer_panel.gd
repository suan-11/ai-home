extends Control
## 电脑操作系统外壳。
## 负责：
## - 打开/关闭整台电脑（动画）
## - 在屏幕区域内切换各个“应用界面”
## - 提供 OS 风格的屏幕切换 API（带预设动画）供后续软件调用

signal closed

enum Transition {
	FADE,
	SLIDE_LEFT,
	SLIDE_RIGHT,
	SLIDE_UP,
	SLIDE_DOWN,
	SCALE,
}

const SCREEN_DESKTOP := "desktop"
const SCREEN_GAMES := "games"
const SCREEN_GOMOKU := "gomoku"
const SCREEN_GRAPHWAR := "graphwar"
const SCREEN_TICTACTOE := "tictactoe"
const SCREEN_BLACKJACK := "blackjack"
const SCREEN_SETTINGS := "settings"
const SCREEN_CHAT := "chat"
const SCREEN_DIARY := "diary"

const DESKTOP_SCENE := preload("res://scenes/ui/desktop_screen.tscn")
const GAME_SELECT_SCENE := preload("res://scenes/ui/game_select.tscn")
const GOMOKU_SCENE := preload("res://scenes/ui/gomoku_game.tscn")
const GRAPHWAR_SCENE := preload("res://scenes/ui/graphwar_game.tscn")
const TICTACTOE_SCENE := preload("res://scenes/ui/tictactoe_game.tscn")
const BLACKJACK_SCENE := preload("res://scenes/ui/blackjack_game.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_screen.tscn")
const CHAT_SCENE := preload("res://scenes/ui/chat_screen.tscn")
const DIARY_SCENE := preload("res://scenes/ui/diary_screen.tscn")

var _is_open := false
var _tween: Tween
var _current_screen: Control = null
var _current_screen_id := ""
var _screen_stack: Array = []

@onready var panel: Control = $Panel
@onready var screen_area: Control = $Panel/ScreenArea


func _ready() -> void:
	visible = false
	$Panel/CloseButton.pressed.connect(close_panel)


func open_panel() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true

	modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)

	_tween = create_tween().set_parallel()
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	_tween.tween_property(panel, "scale", Vector2.ONE, 0.3)

	if _current_screen == null:
		await get_tree().create_timer(0.05).timeout
		show_desktop(Transition.FADE)


func close_panel() -> void:
	if not visible:
		return
	_is_open = false

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_tween.tween_callback(_finish_close)


func _finish_close() -> void:
	visible = false
	closed.emit()


## ---------------- OS 屏幕切换 API ----------------

func show_desktop(transition: int = Transition.FADE) -> void:
	_open_screen(SCREEN_DESKTOP, DESKTOP_SCENE, transition, false)


func open_game_select(transition: int = Transition.SLIDE_LEFT) -> void:
	_open_screen(SCREEN_GAMES, GAME_SELECT_SCENE, transition, true)


func open_gomoku(transition: int = Transition.SLIDE_LEFT) -> void:
	_open_screen(SCREEN_GOMOKU, GOMOKU_SCENE, transition, true)


func open_graphwar(transition: int = Transition.SLIDE_LEFT) -> void:
	_open_screen(SCREEN_GRAPHWAR, GRAPHWAR_SCENE, transition, true)


func open_tictactoe(transition: int = Transition.SLIDE_LEFT) -> void:
	_open_screen(SCREEN_TICTACTOE, TICTACTOE_SCENE, transition, true)


func open_blackjack(transition: int = Transition.SLIDE_LEFT) -> void:
	_open_screen(SCREEN_BLACKJACK, BLACKJACK_SCENE, transition, true)


func open_settings(transition: int = Transition.SLIDE_LEFT) -> void:
	_open_screen(SCREEN_SETTINGS, SETTINGS_SCENE, transition, true)


func open_chat(transition: int = Transition.SLIDE_LEFT) -> void:
	_open_screen(SCREEN_CHAT, CHAT_SCENE, transition, true)


func open_diary(transition: int = Transition.SLIDE_LEFT) -> void:
	_open_screen(SCREEN_DIARY, DIARY_SCENE, transition, true)


func go_back(transition: int = Transition.SLIDE_RIGHT) -> void:
	if _screen_stack.is_empty():
		return
	var target := String(_screen_stack.pop_back())
	match target:
		SCREEN_DESKTOP:
			_open_screen(SCREEN_DESKTOP, DESKTOP_SCENE, transition, false)
		SCREEN_GAMES:
			_open_screen(SCREEN_GAMES, GAME_SELECT_SCENE, transition, false)
		SCREEN_GOMOKU:
			_open_screen(SCREEN_GOMOKU, GOMOKU_SCENE, transition, false)
		SCREEN_GRAPHWAR:
			_open_screen(SCREEN_GRAPHWAR, GRAPHWAR_SCENE, transition, false)
		SCREEN_TICTACTOE:
			_open_screen(SCREEN_TICTACTOE, TICTACTOE_SCENE, transition, false)
		SCREEN_BLACKJACK:
			_open_screen(SCREEN_BLACKJACK, BLACKJACK_SCENE, transition, false)
		SCREEN_SETTINGS:
			_open_screen(SCREEN_SETTINGS, SETTINGS_SCENE, transition, false)
		SCREEN_CHAT:
			_open_screen(SCREEN_CHAT, CHAT_SCENE, transition, false)
		SCREEN_DIARY:
			_open_screen(SCREEN_DIARY, DIARY_SCENE, transition, false)


func get_current_screen_id() -> String:
	return _current_screen_id


func _open_screen(screen_id: String, scene: PackedScene, transition: int, push: bool) -> void:
	var new_screen: Control = scene.instantiate()
	if push:
		_screen_stack.append(_current_screen_id)
	_change_screen(screen_id, new_screen, transition)


func _prepare_screen(screen: Control) -> void:
	screen.anchor_left = 0.0
	screen.anchor_top = 0.0
	screen.anchor_right = 0.0
	screen.anchor_bottom = 0.0
	screen.offset_left = 0.0
	screen.offset_top = 0.0
	screen.offset_right = 0.0
	screen.offset_bottom = 0.0
	screen.position = Vector2.ZERO
	screen.size = screen_area.size


func _change_screen(screen_id: String, new_screen: Control, transition: int) -> void:
	if _current_screen != null and _current_screen_id == screen_id:
		new_screen.queue_free()
		return

	_setup_screen_signals(screen_id, new_screen)

	_prepare_screen(new_screen)
	screen_area.add_child(new_screen)

	var old_screen := _current_screen
	_current_screen = new_screen
	_current_screen_id = screen_id

	if old_screen != null:
		old_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_animate_screen_out(old_screen, transition)
		get_tree().create_timer(0.28).timeout.connect(_free_screen.bind(old_screen))

	_animate_screen_in(new_screen, transition)


func _setup_screen_signals(screen_id: String, screen: Control) -> void:
	match screen_id:
		SCREEN_DESKTOP:
			screen.game_requested.connect(open_game_select)
			screen.chat_requested.connect(open_chat)
			screen.diary_requested.connect(open_diary)
		SCREEN_GAMES:
			screen.gomoku_requested.connect(open_gomoku)
			screen.graphwar_requested.connect(open_graphwar)
			screen.tictactoe_requested.connect(open_tictactoe)
			screen.blackjack_requested.connect(open_blackjack)
			screen.back_requested.connect(func() -> void: go_back(Transition.SLIDE_RIGHT))
		SCREEN_GOMOKU:
			screen.back_requested.connect(func() -> void: go_back(Transition.SLIDE_RIGHT))
		SCREEN_GRAPHWAR:
			screen.back_requested.connect(func() -> void: go_back(Transition.SLIDE_RIGHT))
		SCREEN_TICTACTOE:
			screen.back_requested.connect(func() -> void: go_back(Transition.SLIDE_RIGHT))
		SCREEN_BLACKJACK:
			screen.back_requested.connect(func() -> void: go_back(Transition.SLIDE_RIGHT))
		SCREEN_SETTINGS:
			screen.back_requested.connect(func() -> void: go_back(Transition.SLIDE_RIGHT))
		SCREEN_CHAT:
			screen.back_requested.connect(func() -> void: go_back(Transition.SLIDE_RIGHT))
		SCREEN_DIARY:
			screen.back_requested.connect(func() -> void: go_back(Transition.SLIDE_RIGHT))


func _on_chat_requested() -> void:
	pass


## ---------------- 预设动画 ----------------

func _animate_screen_in(screen: Control, transition: int) -> void:
	match transition:
		Transition.FADE:
			screen.modulate.a = 0.0
			create_tween().tween_property(screen, "modulate:a", 1.0, 0.22)
		Transition.SLIDE_LEFT:
			screen.position = Vector2(screen_area.size.x, 0)
			_slide_tween(screen, Vector2.ZERO, true)
		Transition.SLIDE_RIGHT:
			screen.position = Vector2(-screen_area.size.x, 0)
			_slide_tween(screen, Vector2.ZERO, true)
		Transition.SLIDE_UP:
			screen.position = Vector2(0, screen_area.size.y)
			_slide_tween(screen, Vector2.ZERO, true)
		Transition.SLIDE_DOWN:
			screen.position = Vector2(0, -screen_area.size.y)
			_slide_tween(screen, Vector2.ZERO, true)
		Transition.SCALE:
			screen.pivot_offset = screen.size / 2.0
			screen.scale = Vector2(0.85, 0.85)
			screen.modulate.a = 0.0
			var tween := create_tween().set_parallel()
			var scale_tween := tween.tween_property(screen, "scale", Vector2.ONE, 0.28)
			scale_tween.set_trans(Tween.TRANS_BACK)
			scale_tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(screen, "modulate:a", 1.0, 0.2)


func _animate_screen_out(screen: Control, transition: int) -> void:
	match transition:
		Transition.FADE:
			create_tween().tween_property(screen, "modulate:a", 0.0, 0.2)
		Transition.SLIDE_LEFT:
			_slide_tween(screen, Vector2(-screen_area.size.x, 0), false)
		Transition.SLIDE_RIGHT:
			_slide_tween(screen, Vector2(screen_area.size.x, 0), false)
		Transition.SLIDE_UP:
			_slide_tween(screen, Vector2(0, -screen_area.size.y), false)
		Transition.SLIDE_DOWN:
			_slide_tween(screen, Vector2(0, screen_area.size.y), false)
		Transition.SCALE:
			create_tween().tween_property(screen, "modulate:a", 0.0, 0.18)


func _slide_tween(screen: Control, target_position: Vector2, fade_in: bool) -> void:
	var tween := create_tween().set_parallel()
	var pos_tween := tween.tween_property(screen, "position", target_position, 0.26)
	pos_tween.set_trans(Tween.TRANS_CUBIC)
	pos_tween.set_ease(Tween.EASE_OUT)
	if fade_in:
		tween.tween_property(screen, "modulate:a", 1.0, 0.16)
	else:
		tween.tween_property(screen, "modulate:a", 0.0, 0.2)


func _free_screen(screen: Control) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
