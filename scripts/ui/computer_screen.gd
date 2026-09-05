extends Control
## 仿电脑界面装饰脚本。
## 负责绘制显示器外框、桌面、标题栏和任务栏。
## UI 重绘批次 1：配色从「深蓝桌面」切换为方案 A「暖屋手账」（奶油屏 + 木纹框 + 蜜桃窗钮）。

const C_FRAME_OUTER := Color(0.164706, 0.129412, 0.117647)   # #2A211E 深木棕外框
const C_FRAME_INNER := Color(0.227451, 0.176471, 0.141176)   # #3A2D24 内框
const C_DESKTOP := Color(0.984314, 0.952941, 0.894118)       # #FBF3E4 奶油桌面
const C_TITLEBAR := Color(0.419608, 0.309804, 0.227451)      # #6B4F3A 木纹标题栏
const C_TASKBAR := Color(0.419608, 0.309804, 0.227451)       # #6B4F3A 木纹任务栏
const C_START_BTN := Color(0.909804, 0.658824, 0.486275)     # #E8A87C 蜜桃开始钮
const C_START_DECOR1 := Color(0.984314, 0.952941, 0.894118)  # 奶油装饰
const C_START_DECOR2 := Color(0.85098, 0.72549, 0.54902)     # 暖金装饰
const C_WIN_RED := Color(0.788235, 0.419608, 0.352941)       # #C96B5A 关闭钮
const C_WIN_GRAY := Color(0.8, 0.701961, 0.572549)           # #CCA791 最小化钮
const C_WIN_ACCENT := Color(0.909804, 0.658824, 0.486275)    # #E8A87C 放大钮
const C_GLOW_1 := Color(0.909804, 0.658824, 0.486275, 0.30)  # 蜜桃光斑
const C_GLOW_2 := Color(0.498039, 0.623529, 0.415686, 0.22)  # 温柔绿光斑
const C_GLOW_3 := Color(0.85098, 0.72549, 0.54902, 0.25)     # 暖金光斑
const C_POWER_LED := Color(0.45, 0.85, 0.62, 1.0)            # 指示灯绿


func _draw() -> void:
	var s := size

	# 显示器外框（深木棕描边）
	draw_rect(Rect2(Vector2.ZERO, s), C_FRAME_OUTER)
	draw_rect(Rect2(Vector2(4, 4), s - Vector2(8, 8)), C_FRAME_INNER)

	# 屏幕区域
	var screen := Rect2(Vector2(14, 14), s - Vector2(28, 28))

	# 桌面底色（奶油纸面，模拟暖屋桌面）
	draw_rect(screen, C_DESKTOP)

	# 桌面装饰：柔和的暖色光斑
	draw_circle(screen.position + Vector2(screen.size.x * 0.75, screen.size.y * 0.62), 64.0, C_GLOW_1)
	draw_circle(screen.position + Vector2(screen.size.x * 0.2, screen.size.y * 0.75), 52.0, C_GLOW_2)
	draw_circle(
		screen.position + Vector2(screen.size.x * 0.5, screen.size.y * 0.3),
		40.0,
		C_GLOW_3
	)

	# 标题栏（木纹）
	draw_rect(
		Rect2(screen.position, Vector2(screen.size.x, 28)),
		C_TITLEBAR
	)
	# 标题栏右侧窗口按钮装饰
	draw_rect(
		Rect2(screen.position + Vector2(screen.size.x - 54, 6), Vector2(14, 14)),
		C_WIN_RED
	)
	draw_rect(
		Rect2(screen.position + Vector2(screen.size.x - 36, 6), Vector2(14, 14)),
		C_WIN_GRAY
	)
	draw_rect(
		Rect2(screen.position + Vector2(screen.size.x - 18, 6), Vector2(14, 14)),
		C_WIN_ACCENT
	)

	# 任务栏（木纹）
	draw_rect(
		Rect2(Vector2(screen.position.x, s.y - 50), Vector2(screen.size.x, 36)),
		C_TASKBAR
	)
	# 开始按钮（蜜桃）
	draw_rect(
		Rect2(Vector2(22, s.y - 46), Vector2(40, 28)),
		C_START_BTN
	)
	# 开始按钮上的小块装饰
	draw_rect(
		Rect2(Vector2(30, s.y - 39), Vector2(10, 14)),
		C_START_DECOR1
	)
	draw_rect(
		Rect2(Vector2(42, s.y - 37), Vector2(6, 10)),
		C_START_DECOR2
	)

	# 电源指示灯
	draw_circle(Vector2(s.x - 24, s.y - 32), 3.5, C_POWER_LED)
