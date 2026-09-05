extends Control
## P4：21点（黑杰克，与 AI 对战）。玩家 vs 当前角色（庄家）。
## 规则：A=1/11（自动适应不爆牌），J/Q/K=10；玩家先要牌/停牌，超过 21 爆牌；
## 玩家停牌（或天然黑杰克）后 AI 翻出暗牌并补牌到 ≥17；点数大者胜，相等平局。
## 胜负沿用通用规则：胜 +3 / 平 +1 / 负 0；记录日常事件 blackjack。

signal back_requested
signal game_finished(result: String)
signal game_restarted
signal game_exited

const CARD_W := 36.0
const CARD_H := 50.0
const CARD_GAP := 42.0
const HAND_ORIGIN := Vector2(14, 96)
const AI_HAND_ORIGIN := Vector2(14, 216)

var _deck: Array = []
var _player_hand: Array = []
var _ai_hand: Array = []
var _phase := "player"      # player | dealer | over
var _ai_hole_hidden := true
var _game_over := false
var _char_name := "梅尔"

@onready var status_label: Label = $StatusLabel
@onready var player_label: Label = $PlayerLabel
@onready var ai_label: Label = $AILabel
@onready var hit_button: Button = $HitButton
@onready var stand_button: Button = $StandButton
@onready var restart_button: Button = $RestartButton
@onready var back_button: Button = $BackButton
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/ResultLabel
@onready var restart_result_button: Button = $ResultPanel/RestartResultButton
@onready var exit_result_button: Button = $ResultPanel/ExitResultButton


func _ready() -> void:
	_char_name = CharacterCatalog.get_display_name(GameManager.get_current_char_id())
	hit_button.pressed.connect(_on_hit_pressed)
	stand_button.pressed.connect(_on_stand_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	back_button.pressed.connect(_on_back_pressed)
	restart_result_button.pressed.connect(_on_restart_result_pressed)
	exit_result_button.pressed.connect(_on_exit_result_pressed)
	result_panel.visible = false
	_new_round()


func _draw() -> void:
	var app_rect := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	draw_rect(app_rect, Color(0.16, 0.12, 0.10, 0.98))
	draw_rect(
		Rect2(app_rect.position, Vector2(app_rect.size.x, 30)),
		Color(0.42, 0.31, 0.23)
	)

	_draw_hand(_player_hand, HAND_ORIGIN, false)
	_draw_hand(_ai_hand, AI_HAND_ORIGIN, _ai_hole_hidden)


func _draw_hand(hand: Array, origin: Vector2, face_down: bool) -> void:
	for i in range(hand.size()):
		var pos := origin + Vector2(i * CARD_GAP, 0.0)
		_draw_card(hand[i], pos, face_down and i == 1)


func _draw_card(card: Dictionary, pos: Vector2, face_down: bool) -> void:
	var rect := Rect2(pos, Vector2(CARD_W, CARD_H))
	draw_rect(rect, Color(0.96, 0.94, 0.90))
	draw_rect(rect, Color(0.30, 0.25, 0.30), false, 1.5)
	if face_down:
		draw_rect(
			Rect2(pos + Vector2(5, 5), Vector2(CARD_W - 10, CARD_H - 10)),
			Color(0.42, 0.30, 0.55)
		)
		draw_rect(
			Rect2(pos + Vector2(9, 9), Vector2(CARD_W - 18, CARD_H - 18)),
			Color(0.60, 0.45, 0.72)
		)
		return
	var is_red := str(card["suit"]) in ["♥", "♦"]
	var color := Color(0.88, 0.35, 0.35) if is_red else Color(0.22, 0.22, 0.28)
	var font := get_theme_default_font()
	draw_string(font, pos + Vector2(5, 15), str(card["rank"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	draw_string(font, pos + Vector2(5, 32), str(card["suit"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


## ---------------- 牌堆 / 计分 ----------------


func _build_deck() -> Array:
	var deck: Array = []
	var ranks := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	var suits := ["♠", "♥", "♦", "♣"]
	for suit in suits:
		for rank in ranks:
			deck.append({"rank": rank, "suit": suit})
	return deck


func _draw_card_safe() -> Dictionary:
	if _deck.is_empty():
		_deck = _build_deck()
		_deck.shuffle()
	return _deck.pop_back()


func _hand_total(hand: Array) -> int:
	var total := 0
	var aces := 0
	for card in hand:
		var rank := str(card["rank"])
		if rank == "A":
			total += 11
			aces += 1
		elif rank in ["J", "Q", "K"]:
			total += 10
		else:
			total += int(rank)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


func _hand_is_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and _hand_total(hand) == 21


func _hand_text(hand: Array) -> String:
	var parts: PackedStringArray = []
	for card in hand:
		parts.append(str(card["rank"]) + str(card["suit"]))
	var text := ""
	for i in range(parts.size()):
		if i > 0:
			text += " "
		text += parts[i]
	return text


## ---------------- 回合流程 ----------------


func _new_round() -> void:
	_deck = _build_deck()
	_deck.shuffle()
	_player_hand = []
	_ai_hand = []
	_game_over = false
	_ai_hole_hidden = true
	_phase = "player"
	result_panel.visible = false

	for _i in range(2):
		_player_hand.append(_draw_card_safe())
	_ai_hand.append(_draw_card_safe())
	_ai_hand.append(_draw_card_safe())

	hit_button.disabled = false
	stand_button.disabled = false
	if _hand_is_blackjack(_player_hand):
		hit_button.disabled = true
		stand_button.disabled = true
		phase_dealer("黑杰克！%s翻牌…" % _char_name)
		_update_labels(false)
		queue_redraw()
		get_tree().create_timer(0.7).timeout.connect(_dealer_play_async)
		return

	status_label.text = "你的回合：要牌或停牌"
	_update_labels(false)
	queue_redraw()


func _on_hit_pressed() -> void:
	if _game_over or _phase != "player":
		return
	_player_hand.append(_draw_card_safe())
	_update_labels(false)
	queue_redraw()
	if _hand_total(_player_hand) > 21:
		_end_game("你爆牌了（超过 21 点）", "lose")
		return
	status_label.text = "还要吗？或停牌"


func _on_stand_pressed() -> void:
	if _game_over or _phase != "player":
		return
	_dealer_play_async()


func _dealer_play_async() -> void:
	if _game_over:
		return
	phase_dealer("%s翻牌：%d 点…" % [_char_name, _hand_total(_ai_hand)])
	_update_labels(true)
	queue_redraw()
	await get_tree().create_timer(0.6).timeout
	while not _game_over and _hand_total(_ai_hand) < 17:
		_ai_hand.append(_draw_card_safe())
		status_label.text = "%s要牌：%d 点…" % [_char_name, _hand_total(_ai_hand)]
		_update_labels(true)
		queue_redraw()
		await get_tree().create_timer(0.55).timeout
	if _game_over:
		return
	_compare_and_finish()


func phase_dealer(text: String) -> void:
	_phase = "dealer"
	_ai_hole_hidden = false
	hit_button.disabled = true
	stand_button.disabled = true
	status_label.text = text


func _compare_and_finish() -> void:
	var player_total := _hand_total(_player_hand)
	var ai_total := _hand_total(_ai_hand)
	if ai_total > 21:
		_end_game("%s 爆牌了，你赢了！" % _char_name, "win")
		return
	if player_total > ai_total:
		if _hand_is_blackjack(_player_hand):
			_end_game("黑杰克！你赢了！", "win")
		else:
			_end_game("你赢了！", "win")
	elif player_total < ai_total:
		_end_game("%s 赢了" % _char_name, "lose")
	else:
		_end_game("平局", "draw")


## ---------------- 结算 / 结束 ----------------


func _end_game(message: String, result: String) -> void:
	_game_over = true
	_phase = "over"
	hit_button.disabled = true
	stand_button.disabled = true
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
	var char_id := GameManager.get_current_char_id()
	var delta := GameManager.on_game_finished(char_id, "win", "21点")
	MemoryManager.record_daily_event(char_id, "blackjack", "win")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[Blackjack] 胜利，好感度 +%d" % delta)


func _on_game_lost() -> void:
	var char_id := GameManager.get_current_char_id()
	GameManager.on_game_finished(char_id, "lose", "21点")
	MemoryManager.record_daily_event(char_id, "blackjack", "lose")
	print("[Blackjack] 失败接口预留")


func _on_draw() -> void:
	var char_id := GameManager.get_current_char_id()
	var delta := GameManager.on_game_finished(char_id, "draw", "21点")
	MemoryManager.record_daily_event(char_id, "blackjack", "draw")
	if delta > 0:
		result_label.text += "\n好感度 +%d" % delta
	print("[Blackjack] 平局，好感度 +%d" % delta)


func _update_labels(revealed: bool) -> void:
	player_label.text = "你的手牌（%d 张，%d 点）：%s" % [
		_player_hand.size(), _hand_total(_player_hand), _hand_text(_player_hand),
	]
	var ai_total_text := "？"
	if revealed:
		ai_total_text = "%d 点" % _hand_total(_ai_hand)
	ai_label.text = "%s的手牌（%d 张，%s）：%s" % [
		_char_name, _ai_hand.size(), ai_total_text, _hand_text(_ai_hand),
	]


## ---------------- 按钮 ----------------


func _on_restart_pressed() -> void:
	_new_round()
	game_restarted.emit()


func _on_restart_result_pressed() -> void:
	_on_restart_pressed()


func _on_back_pressed() -> void:
	game_exited.emit()
	back_requested.emit()


func _on_exit_result_pressed() -> void:
	game_exited.emit()
	back_requested.emit()
