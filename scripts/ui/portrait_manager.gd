extends TextureRect
## P3 立绘差分：根据状态/事件切换左侧立绘。
## 持久状态（开心/低落）来自 StatusManager 阈值；临时表情（惊讶/害羞/走神等）由事件触发。
## 优先级（高→低）：惊讶 > 害羞 > 生气 > 开心 > 低落 > 走神 > 默认。

const TEXTURES := {
	"default": preload("res://assets/chars/char_03/portraits/default.png"),
	"happy": preload("res://assets/chars/char_03/portraits/happy.png"),
	"low": preload("res://assets/chars/char_03/portraits/low.png"),
	"shy": preload("res://assets/chars/char_03/portraits/shy.png"),
	"distracted": preload("res://assets/chars/char_03/portraits/distracted.png"),
	"surprised": preload("res://assets/chars/char_03/portraits/surprised.png"),
	"angry": preload("res://assets/chars/char_03/portraits/angry.png"),
	"blushing_worried": preload("res://assets/chars/char_03/portraits/blushing_worried.png"),
}

const PRIORITY := ["surprised", "shy", "angry", "happy", "low", "distracted"]
const MOOD_HAPPY := 80
const MOOD_LOW := 30
const SATIETY_LOW := 30
const CHECK_INTERVAL := 0.25

var _current := "default"
var _temp_expiry: Dictionary = {}
var _check_timer := 0.0


func _ready() -> void:
	StatusManager.status_changed.connect(_on_status_changed)
	_refresh()


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_refresh()


## 事件触发临时表情，duration 秒；到期自动回落到持久状态。
func set_expression(kind: String, duration: float = 2.0) -> void:
	if not TEXTURES.has(kind) or duration <= 0.0:
		return
	_temp_expiry[kind] = Time.get_ticks_msec() / 1000.0 + duration
	_refresh()


func _on_status_changed() -> void:
	_refresh()


func _refresh() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var expired: Array = []
	for kind in _temp_expiry.keys():
		if _temp_expiry[kind] <= now:
			expired.append(kind)
	for kind in expired:
		_temp_expiry.erase(kind)

	var active := ""
	for kind in PRIORITY:
		if _temp_expiry.has(kind):
			active = kind
			break
	if active.is_empty():
		active = _persistent_kind()
	_apply(active)


func _persistent_kind() -> String:
	var mood := int(StatusManager.get_mood())
	var satiety := int(StatusManager.get_satiety())
	if mood >= MOOD_HAPPY:
		return "happy"
	if mood < MOOD_LOW or satiety < SATIETY_LOW:
		return "low"
	return "default"


func _apply(kind: String) -> void:
	if kind == _current:
		return
	_current = kind
	if TEXTURES.has(kind):
		texture = TEXTURES[kind]
