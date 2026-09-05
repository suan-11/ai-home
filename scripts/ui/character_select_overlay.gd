extends Control
## P4 多角色切换：主界面「角色」按钮弹出的角色选择浮层。
## - 从 CharacterCatalog 扫描可用角色（基础素材：persona.json + sprites + portrait.png）
## - 列表显示立绘缩略图 / 名字 / 性格摘要 / 好感度；点击即切换（直接切换，无二次确认）
## - 当前角色显示「（当前）」并禁用

signal closed
signal character_selected(char_id: String)

var _is_open := false
var _tween: Tween

@onready var list_container: VBoxContainer = $Panel/ScrollContainer/ListContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Panel/CloseButton.pressed.connect(close_overlay)
	$Backdrop.gui_input.connect(_on_backdrop_input)


func open_overlay() -> void:
	if _is_open:
		return
	_is_open = true
	_refresh()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)


func close_overlay() -> void:
	if not _is_open:
		return
	_is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
	closed.emit()


func _refresh() -> void:
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()

	var characters := CharacterCatalog.list_characters()
	if characters.is_empty():
		var empty := Label.new()
		empty.text = "暂无可用角色"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty)
		return

	var current_id := GameManager.get_current_char_id()
	for info in characters:
		var id := str(info["id"])
		_add_character_row(info, id == current_id)


func _add_character_row(info: Dictionary, is_current: bool) -> void:
	var id := str(info["id"])
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 58)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_current:
		row.modulate = Color(1.0, 1.0, 1.0, 0.55)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(42, 42)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path := str(info.get("portrait_path", ""))
	if not portrait_path.is_empty():
		var tex: Texture2D = load(portrait_path)
		if tex != null:
			thumb.texture = tex
	hbox.add_child(thumb)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label := Label.new()
	var lv := GameManager.get_affection_level(id)
	var rank := GameManager.get_affection_rank_name(id)
	var exp := GameManager.get_affection_exp(id)
	var next := GameManager.get_affection_next_exp(id)
	var progress_text := "MAX" if next <= 0 else "%d/%d" % [exp, next]
	var suffix := "（当前）　" if is_current else "　"
	name_label.text = "%s%s好感 Lv.%d %s · %s" % [str(info.get("display_name", id)), suffix, lv, rank, progress_text]
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = _describe(info)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.modulate = Color(1.0, 1.0, 1.0, 0.8)
	vbox.add_child(desc_label)

	list_container.add_child(row)
	if not is_current:
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				_on_character_pressed(id)
		)


func _describe(info: Dictionary) -> String:
	var parts: Array[String] = []
	var personality := str(info.get("personality", ""))
	if not personality.is_empty():
		parts.append(personality)
	var greeting := str(info.get("greeting", ""))
	if not greeting.is_empty():
		parts.append("「%s」" % greeting)
	if not info.get("has_interactions", false):
		parts.append("（无互动配置，后续补充）")
	if not info.get("has_portraits", false):
		parts.append("（暂无差分立绘，使用单张立绘）")
	if parts.is_empty():
		return "等待了解她…"
	return " · ".join(parts)


func _on_character_pressed(char_id: String) -> void:
	close_overlay()
	if GameManager.set_current_char_id(char_id):
		character_selected.emit(char_id)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		close_overlay()
