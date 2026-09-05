extends Control
## 游戏选择屏幕（UI 重构批次 1：注册表驱动）。
## 新增小游戏：只需在 GAMES 注册表加一项（id/name/desc），
## 并在 _on_game_pressed 的 match 中发出对应信号即可，无需再改场景。

signal back_requested
signal gomoku_requested
signal graphwar_requested
signal tictactoe_requested
signal blackjack_requested
signal snake_requested

const GAMES := [
	{"id": "gomoku", "name": "五子棋", "desc": "与 AI 对弈"},
	{"id": "graphwar", "name": "Graphwar 函数对打", "desc": "输入 f(x) 击毁对方"},
	{"id": "tictactoe", "name": "井字棋", "desc": "三连即胜"},
	{"id": "blackjack", "name": "21点", "desc": "AI 庄家"},
	{"id": "snake", "name": "贪吃蛇", "desc": "与 AI 同场赛跑"},
	{"id": "future", "name": "更多游戏（持续添加中…）", "desc": "敬请期待"},
]

@onready var status_bar: Label = $WindowPanel/StatusBar
@onready var game_list: VBoxContainer = $WindowPanel/ScrollContainer/GameList


func _ready() -> void:
	_build_buttons()
	$WindowPanel/TitleBar.back_requested.connect(_on_back_pressed)


func _build_buttons() -> void:
	for game: Dictionary in GAMES:
		var btn := Button.new()
		btn.text = "%s\n%s" % [game["name"], game["desc"]]
		btn.custom_minimum_size = Vector2(0, UIConstants.LIST_ITEM_H)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_game_pressed.bind(game["id"]))
		game_list.add_child(btn)

	# 返回桌面固定在列表底部
	var back_btn := Button.new()
	back_btn.text = "返回桌面"
	back_btn.custom_minimum_size = Vector2(0, UIConstants.LIST_ITEM_H)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_back_pressed)
	game_list.add_child(back_btn)


func _on_game_pressed(game_id: String) -> void:
	match game_id:
		"gomoku":
			status_bar.text = "正在进入五子棋…"
			gomoku_requested.emit()
		"graphwar":
			status_bar.text = "正在进入函数对打…"
			graphwar_requested.emit()
		"tictactoe":
			status_bar.text = "正在进入井字棋…"
			tictactoe_requested.emit()
		"blackjack":
			status_bar.text = "正在进入 21点…"
			blackjack_requested.emit()
		"snake":
			status_bar.text = "正在进入贪吃蛇…"
			snake_requested.emit()
		"future":
			status_bar.text = "后续游戏待添加"


func _on_back_pressed() -> void:
	back_requested.emit()
