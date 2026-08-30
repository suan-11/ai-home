extends Control
## 角色收到消息时的头顶特效：黄色「！」弹出、弹跳后淡出。

@onready var label: Label = $Label

var _tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size / 2.0


func play_effect(duration: float = 1.2) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.4, 0.4)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.08)
	_tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func() -> void: visible = false)
