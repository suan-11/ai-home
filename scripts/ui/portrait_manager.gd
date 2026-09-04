extends TextureRect
## P3 立绘差分 + P4 多角色：根据状态/事件切换左侧立绘。
## 持久状态（开心/低落）来自 StatusManager 阈值；临时表情（惊讶/害羞/走神等）由事件触发。
## 优先级（高→低）：惊讶 > 害羞 > 生气 > 开心 > 低落 > 走神 > 默认。
## 多角色：set_character(char_id) 加载该角色 portraits/ 下的表情；
## 缺失的表情回落到单张 portrait.png（降级）。

const PORTRAIT_KINDS := [
	"default", "happy", "low", "shy", "distracted", "surprised", "angry", "blushing_worried",
]
const PRIORITY := ["surprised", "shy", "angry", "happy", "low", "distracted"]
const MOOD_HAPPY := 80
const MOOD_LOW := 30
const SATIETY_LOW := 30
const CHECK_INTERVAL := 0.25

var _textures: Dictionary = {}      # kind -> Texture2D
var _base_texture: Texture2D = null # 单张原图兜底
var _char_id := "char_03"
var _current := "default"
var _temp_expiry: Dictionary = {}
var _check_timer := 0.0


func _ready() -> void:
	StatusManager.status_changed.connect(_on_status_changed)
	set_character(GameManager.get_current_char_id())


## 多角色切换：重新加载该角色立绘并刷新。
func set_character(char_id: String) -> void:
	if char_id.is_empty():
		return
	_char_id = char_id
	_textures = {}
	_temp_expiry = {}
	_current = ""

	_base_texture = _load_texture("res://assets/chars/%s/portrait.png" % char_id)
	for kind in PORTRAIT_KINDS:
		var path := "res://assets/chars/%s/portraits/%s.png" % [char_id, kind]
		var tex := _load_texture(path)
		_textures[kind] = tex if tex != null else _base_texture

	# 立绘本身也要换成新角色
	if _base_texture != null:
		texture = _base_texture
	_refresh()


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_refresh()


## 事件触发临时表情，duration 秒；到期自动回落到持久状态。
func set_expression(kind: String, duration: float = 2.0) -> void:
	if not _textures.has(kind) or duration <= 0.0:
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
	var tex: Texture2D = _textures.get(kind, _base_texture)
	if tex != null:
		texture = tex


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	return tex if tex != null else null
