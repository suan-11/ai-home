extends Control
## 仿电脑界面装饰脚本。
## 负责绘制显示器外框、桌面、标题栏和任务栏。

func _draw() -> void:
	var s := size

	# 显示器外框（深色边框）
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.08, 0.08, 0.10))
	draw_rect(Rect2(Vector2(4, 4), s - Vector2(8, 8)), Color(0.13, 0.13, 0.16))

	# 屏幕区域
	var screen := Rect2(Vector2(14, 14), s - Vector2(28, 28))

	# 桌面底色（深蓝，模拟系统桌面）
	draw_rect(screen, Color(0.17, 0.23, 0.36))

	# 桌面装饰：柔和的圆形光斑
	var glow := Color(0.35, 0.55, 0.85, 0.18)
	draw_circle(screen.position + Vector2(screen.size.x * 0.75, screen.size.y * 0.62), 64.0, glow)
	draw_circle(screen.position + Vector2(screen.size.x * 0.2, screen.size.y * 0.75), 52.0, glow)
	draw_circle(
		screen.position + Vector2(screen.size.x * 0.5, screen.size.y * 0.3),
		40.0,
		Color(0.6, 0.75, 0.95, 0.12)
	)

	# 标题栏
	draw_rect(
		Rect2(screen.position, Vector2(screen.size.x, 28)),
		Color(0.22, 0.28, 0.42)
	)
	# 标题栏右侧窗口按钮装饰
	draw_rect(
		Rect2(screen.position + Vector2(screen.size.x - 54, 6), Vector2(14, 14)),
		Color(0.55, 0.35, 0.35)
	)
	draw_rect(
		Rect2(screen.position + Vector2(screen.size.x - 36, 6), Vector2(14, 14)),
		Color(0.45, 0.45, 0.50)
	)
	draw_rect(
		Rect2(screen.position + Vector2(screen.size.x - 18, 6), Vector2(14, 14)),
		Color(0.35, 0.55, 0.75)
	)

	# 任务栏
	draw_rect(
		Rect2(Vector2(screen.position.x, s.y - 50), Vector2(screen.size.x, 36)),
		Color(0.10, 0.11, 0.15)
	)
	# 开始按钮
	draw_rect(
		Rect2(Vector2(22, s.y - 46), Vector2(40, 28)),
		Color(0.25, 0.50, 0.80)
	)
	# 开始按钮上的小块装饰
	draw_rect(
		Rect2(Vector2(30, s.y - 39), Vector2(10, 14)),
		Color(0.75, 0.95, 1.0)
	)
	draw_rect(
		Rect2(Vector2(42, s.y - 37), Vector2(6, 10)),
		Color(0.55, 0.80, 0.95)
	)

	# 电源指示灯
	draw_circle(Vector2(s.x - 24, s.y - 32), 3.5, Color(0.40, 0.95, 0.55))
