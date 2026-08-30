extends Control
## 帮助浮层：两种模式
## - 攻略（首次进入游戏自动弹出）
## - 家具功能一览（主界面右侧「家具介绍」按钮）
## 内容由 GameMain 提供；关闭时 emit closed。

signal closed

const GUIDE_TEXT := """[color=#f2d9a0][b]欢迎回到温馨小屋喵～[/b][/color]

[b]基础操作[/b]
- 左键点击地板/家具：点击处会出现一个吸引物（爱心/小鱼干等，设置里可换），梅尔停顿、头顶冒「！」后被吸引过去，到达后物品消失；到达家具旁会自动触发交互
- 点击「电脑」：打开仿电脑系统（游戏选择 / 五子棋 / 聊天 / 日记）
- 点击「布置台」：自定义家具位置（长按拾起 → 点击放下）
- 梅尔偶尔会走神（冒「？」），好感度越高越愿意回应你的引导

[b]界面[/b]
- 右上角「设置」：通用 / 显示 / 音频 / AI 设置（配置 API 后聊天才能用）
- 「设置」下方「手机」：随时给梅尔发消息，她会回复、冒气泡，还可能被指令吸引去家具旁
- 右侧「家具介绍」：随时查看每件家具的功能
- 左侧立绘：梅尔（当前角色，会随着聊天次数记录记忆）

[b]小技巧[/b]
- F11 切换全屏
- 每局五子棋结束会结算好感度（胜 +3 / 平 +1 / 负 0）"""

var _is_open := false
var _tween: Tween

@onready var title_label: Label = $Panel/TitleLabel
@onready var content_label: RichTextLabel = $Panel/ScrollContainer/ContentLabel
@onready var close_button: Button = $Panel/CloseButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close_overlay)


func setup_guide() -> void:
	title_label.text = "新手攻略"
	content_label.text = GUIDE_TEXT
	close_button.text = "开始游戏"


func setup_furniture(furniture: Array) -> void:
	title_label.text = "家具功能一览"
	var lines: Array[String] = []
	for f in furniture:
		lines.append(
			"[color=#f2d9a0]■ %s[/color]（交互：%s）\n%s\n"
			% [str(f["name"]), str(f["interaction"]), str(f["desc"])]
		)
	lines.append(
		"\n提示：除「电脑」「布置台」外，其余家具交互为预留功能，"
		+ "当前点击会触发互动并计入好感度/日记（每种家具每天首次 +1）。"
	)
	content_label.text = "\n".join(lines)
	close_button.text = "关闭"


func open_overlay() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)


func close_overlay() -> void:
	if not _is_open:
		return
	_is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.16)
	_tween.tween_callback(_finish_close)


func _finish_close() -> void:
	visible = false
	closed.emit()
