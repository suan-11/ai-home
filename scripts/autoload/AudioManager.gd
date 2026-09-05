extends Node
## P4 BGM：房间背景音乐循环播放。
## - 音频：assets/sfx/bgm_room.wav（tools/gen_bgm.py 生成，16 秒暖色像素风循环）
## - 音量 / 静音跟随 ConfigManager audio 设置（设置界面「音频」页即时生效）
## - 用 AudioStreamWAV 的 loop 属性循环；设置变更时由 AudioManager.apply_audio_settings() 应用

const BGM_PATH := "res://assets/sfx/bgm_room.wav"

var _bgm: AudioStreamPlayer = null


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	var stream = load(BGM_PATH)
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		var total_frames := int(wav.get_length() * wav.mix_rate)
		wav.loop_end = total_frames if total_frames > 0 else 1
	_bgm.stream = stream
	add_child(_bgm)
	apply_audio_settings()


## 应用设置：静音则停止，否则按 bgm_volume 播放（0 音量停止）。
func apply_audio_settings() -> void:
	if _bgm == null:
		return
	var muted := bool(ConfigManager.get_value("audio", "muted", false))
	var volume := clampf(float(ConfigManager.get_value("audio", "bgm_volume", 0.6)), 0.0, 1.0)
	if muted or volume <= 0.0:
		_bgm.stop()
		return
	_bgm.volume_db = linear_to_db(volume)
	if not _bgm.playing:
		_bgm.play()
