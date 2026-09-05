extends Node
## P4 BGM：从用户自备的 assets/bgm/ 文件夹读取背景音乐。
## - 支持格式：wav / ogg / mp3 / flac（Godot 导入后可直接播放）
## - 读取全部文件 → 按文件名排序 → 循环轮播；文件夹为空则**不播放**
## - 音量 / 静音跟随 ConfigManager audio 设置（设置界面「音频」页即时生效）

const BGM_DIR := "res://assets/bgm"
const SUPPORTED_EXTS := ["wav", "ogg", "mp3", "flac"]

var _bgm: AudioStreamPlayer = null
var _playlist: Array = []
var _index := 0


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	add_child(_bgm)
	_bgm.finished.connect(_on_finished)
	_load_playlist()
	apply_audio_settings()


## 扫描 assets/bgm/，收集支持的音频并按文件名排序。
func _load_playlist() -> void:
	_playlist = []
	_index = 0
	var dir := DirAccess.open(BGM_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var files: Array = []
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and _is_supported(entry):
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for file_name in files:
		var stream = load("%s/%s" % [BGM_DIR, file_name])
		if stream == null:
			continue
		_setup_loop(stream)
		_playlist.append(stream)


func _is_supported(file_name: String) -> bool:
	var name := file_name.to_lower()
	for ext in SUPPORTED_EXTS:
		if name.ends_with("." + ext):
			return true
	return false


func _setup_loop(stream) -> void:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		var total_frames := int(wav.get_length() * wav.mix_rate)
		wav.loop_end = total_frames if total_frames > 0 else 1
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true


## 一首结束 → 下一首；到结尾回到第一首（轮播）。
func _on_finished() -> void:
	if _playlist.is_empty():
		return
	_index = (_index + 1) % _playlist.size()
	_play_current()


## 应用设置：静音/无 BGM/音量为 0 则停止，否则按 bgm_volume 播放当前曲目。
func apply_audio_settings() -> void:
	if _bgm == null:
		return
	var muted := bool(ConfigManager.get_value("audio", "muted", false))
	var volume := clampf(float(ConfigManager.get_value("audio", "bgm_volume", 0.6)), 0.0, 1.0)
	if muted or volume <= 0.0 or _playlist.is_empty():
		_bgm.stop()
		return
	_bgm.volume_db = linear_to_db(volume)
	if not _bgm.playing:
		_play_current()


func _play_current() -> void:
	if _playlist.is_empty():
		return
	_bgm.stream = _playlist[_index]
	_bgm.play()
