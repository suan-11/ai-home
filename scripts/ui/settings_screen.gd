extends Control
## 设置应用：顶部标签页 + 下方子界面。
## 可保存到 ConfigManager（user://config.json）。

signal back_requested

const GAME_MAIN_SCRIPT := preload("res://scripts/GameMain.gd")
const TAB_GENERAL := "general"
const TAB_DISPLAY := "display"
const TAB_AUDIO := "audio"
const TAB_AI := "ai"

var _current_tab := ""

@onready var tab_bar: HBoxContainer = $TabBar
@onready var content_area: Control = $ContentArea
@onready var status_label: Label = $StatusLabel

@onready var general_panel: Control = $ContentArea/GeneralPanel
@onready var display_panel: Control = $ContentArea/DisplayPanel
@onready var audio_panel: Control = $ContentArea/AudioPanel
@onready var ai_panel: Control = $ContentArea/AiPanel

@onready var owner_edit: LineEdit = $ContentArea/GeneralPanel/OwnerEdit
@onready var auto_save_check: CheckButton = $ContentArea/GeneralPanel/AutoSaveCheck
@onready var attract_option: OptionButton = $ContentArea/GeneralPanel/AttractOption
@onready var speed_option: OptionButton = $ContentArea/GeneralPanel/SpeedOption

@onready var pixel_scale_check: CheckButton = $ContentArea/DisplayPanel/PixelScaleCheck
@onready var fps_check: CheckButton = $ContentArea/DisplayPanel/FpsCheck
@onready var fullscreen_check: CheckButton = $ContentArea/DisplayPanel/FullscreenCheck

@onready var bgm_slider: HSlider = $ContentArea/AudioPanel/BgmSlider
@onready var sfx_slider: HSlider = $ContentArea/AudioPanel/SfxSlider
@onready var muted_check: CheckButton = $ContentArea/AudioPanel/MutedCheck

@onready var api_base_edit: LineEdit = $ContentArea/AiPanel/ApiBaseEdit
@onready var api_key_edit: LineEdit = $ContentArea/AiPanel/ApiKeyEdit
@onready var model_edit: LineEdit = $ContentArea/AiPanel/ModelEdit
@onready var max_tokens_edit: LineEdit = $ContentArea/AiPanel/MaxTokensEdit
@onready var temp_slider: HSlider = $ContentArea/AiPanel/TempSlider
@onready var temp_value_label: Label = $ContentArea/AiPanel/TempValueLabel


func _ready() -> void:
	$TabBar/GeneralTab.pressed.connect(_on_tab_pressed.bind(TAB_GENERAL))
	$TabBar/DisplayTab.pressed.connect(_on_tab_pressed.bind(TAB_DISPLAY))
	$TabBar/AudioTab.pressed.connect(_on_tab_pressed.bind(TAB_AUDIO))
	$TabBar/AiTab.pressed.connect(_on_tab_pressed.bind(TAB_AI))
	$BackButton.pressed.connect(_on_back_pressed)
	$ContentArea/AiPanel/SaveButton.pressed.connect(_on_save_pressed)
	temp_slider.value_changed.connect(_on_temp_slider_changed)

	_load_values()
	# 音频控件即时生效（BGM/静音直接应用，SFX 保存时随配置生效）
	bgm_slider.value_changed.connect(_on_bgm_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	muted_check.toggled.connect(_on_muted_toggled)
	_show_tab(TAB_GENERAL)


func _load_values() -> void:
	owner_edit.text = ConfigManager.get_value("general", "owner_name", "主人")
	auto_save_check.button_pressed = ConfigManager.get_value("general", "auto_save", true)
	_setup_attract_options()
	_setup_speed_options()

	pixel_scale_check.button_pressed = ConfigManager.get_value("display", "pixel_scale", 2) >= 2
	fps_check.button_pressed = ConfigManager.get_value("display", "show_fps", false)
	fullscreen_check.button_pressed = ConfigManager.get_value("display", "start_fullscreen", false)

	bgm_slider.value = float(ConfigManager.get_value("audio", "bgm_volume", 0.6))
	sfx_slider.value = float(ConfigManager.get_value("audio", "sfx_volume", 0.8))
	muted_check.button_pressed = ConfigManager.get_value("audio", "muted", false)

	api_base_edit.text = ConfigManager.get_value("ai", "api_base", "")
	api_key_edit.text = ConfigManager.get_value("ai", "api_key", "")
	model_edit.text = ConfigManager.get_value("ai", "model", "")
	max_tokens_edit.text = str(ConfigManager.get_value("ai", "max_tokens", 512))
	temp_slider.value = float(ConfigManager.get_value("ai", "temperature", 0.8))
	_update_temp_value()


func _show_tab(tab: String) -> void:
	general_panel.visible = tab == TAB_GENERAL
	display_panel.visible = tab == TAB_DISPLAY
	audio_panel.visible = tab == TAB_AUDIO
	ai_panel.visible = tab == TAB_AI

	for btn in [$TabBar/GeneralTab, $TabBar/DisplayTab, $TabBar/AudioTab, $TabBar/AiTab]:
		var selected: bool = (
			(btn == $TabBar/GeneralTab and tab == TAB_GENERAL)
			or (btn == $TabBar/DisplayTab and tab == TAB_DISPLAY)
			or (btn == $TabBar/AudioTab and tab == TAB_AUDIO)
			or (btn == $TabBar/AiTab and tab == TAB_AI)
		)
		btn.modulate = Color(1, 1, 1) if selected else Color(0.6, 0.6, 0.6)

	var panel := _panel_for_tab(tab)
	panel.modulate.a = 0.0
	panel.position = Vector2(0, 8)
	var tween := create_tween().set_parallel()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	var pos_tween := tween.tween_property(panel, "position", Vector2.ZERO, 0.22)
	pos_tween.set_trans(Tween.TRANS_CUBIC)
	pos_tween.set_ease(Tween.EASE_OUT)
	_current_tab = tab
	status_label.text = "设置：%s" % tab


func _panel_for_tab(tab: String) -> Control:
	match tab:
		TAB_DISPLAY:
			return display_panel
		TAB_AUDIO:
			return audio_panel
		TAB_AI:
			return ai_panel
	return general_panel


func _setup_attract_options() -> void:
	## 引导物品种类：随机（默认）或固定某一种；数据源 GameMain.ATTRACT_ITEMS。
	attract_option.clear()
	attract_option.add_item("随机（多种混合）")
	attract_option.set_item_metadata(0, "random")
	var items: Array = GAME_MAIN_SCRIPT.ATTRACT_ITEMS
	for i in range(items.size()):
		var item: Dictionary = items[i]
		attract_option.add_item(str(item["name"]))
		attract_option.set_item_metadata(i + 1, str(item["id"]))
	var current := str(ConfigManager.get_value("general", "attract_item", "random"))
	var idx := 0
	for i in range(attract_option.item_count):
		if str(attract_option.get_item_metadata(i)) == current:
			idx = i
			break
	attract_option.selected = idx


func _setup_speed_options() -> void:
	## 状态变化速度：测试用途，正式版移除（general.dev_state_speed）。
	speed_option.clear()
	var speeds := [1.0, 5.0, 10.0]
	var labels := ["×1（正常，正式版用）", "×5（加速测试）", "×10（快速测试）"]
	for i in range(speeds.size()):
		speed_option.add_item(labels[i])
		speed_option.set_item_metadata(i, speeds[i])
	var current := float(ConfigManager.get_value("general", "dev_state_speed", 1.0))
	var idx := 0
	for i in range(speed_option.item_count):
		if float(speed_option.get_item_metadata(i)) == current:
			idx = i
			break
	speed_option.selected = idx


func _on_tab_pressed(tab: String) -> void:
	_show_tab(tab)


func _on_temp_slider_changed(_value: float) -> void:
	_update_temp_value()


func _update_temp_value() -> void:
	temp_value_label.text = "%.2f" % temp_slider.value


func _on_bgm_slider_changed(value: float) -> void:
	ConfigManager.set_value("audio", "bgm_volume", value)
	AudioManager.apply_audio_settings()


func _on_sfx_slider_changed(value: float) -> void:
	ConfigManager.set_value("audio", "sfx_volume", value)


func _on_muted_toggled(value: bool) -> void:
	ConfigManager.set_value("audio", "muted", value)
	AudioManager.apply_audio_settings()


func _on_save_pressed() -> void:
	ConfigManager.set_value("general", "owner_name", owner_edit.text)
	ConfigManager.set_value("general", "auto_save", auto_save_check.button_pressed)
	ConfigManager.set_value("general", "attract_item", attract_option.get_item_metadata(attract_option.selected))
	ConfigManager.set_value("general", "dev_state_speed", speed_option.get_item_metadata(speed_option.selected))
	ConfigManager.set_value("display", "pixel_scale", 2 if pixel_scale_check.button_pressed else 1)
	ConfigManager.set_value("display", "show_fps", fps_check.button_pressed)
	ConfigManager.set_value("display", "start_fullscreen", fullscreen_check.button_pressed)
	ConfigManager.set_value("audio", "bgm_volume", bgm_slider.value)
	ConfigManager.set_value("audio", "sfx_volume", sfx_slider.value)
	ConfigManager.set_value("audio", "muted", muted_check.button_pressed)
	ConfigManager.set_value("ai", "api_base", api_base_edit.text)
	ConfigManager.set_value("ai", "api_key", api_key_edit.text)
	ConfigManager.set_value("ai", "model", model_edit.text)
	ConfigManager.set_value("ai", "max_tokens", int(max_tokens_edit.text))
	ConfigManager.set_value("ai", "temperature", temp_slider.value)
	status_label.text = "设置已保存"


func _on_back_pressed() -> void:
	back_requested.emit()
