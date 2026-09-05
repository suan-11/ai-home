extends Node
## P4 BGM：扫描「用户自备」的背景音乐文件夹。
## 查找顺序：① 可执行文件旁 assets/bgm/（打包版，玩家可放）② res://assets/bgm（编辑器开发）③ user://bgm（备用）
## - 支持格式：wav / ogg / mp3 / flac
## - 读取全部文件 → 按文件名排序 → 循环轮播；全部为空则**不播放**
## - 音量 / 静音跟随 ConfigManager audio 设置（设置界面「音频」页即时生效）

const BGM_DIR_RES := "res://assets/bgm"
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


## 扫描各 BGM 根目录，收集支持的音频并按文件名排序。
func _load_playlist() -> void:
	_playlist = []
	_index = 0
	for root in _bgm_roots():
		_collect_dir(root)


## 查找顺序：打包版 exe 旁 assets/bgm/ > 开发版 res://assets/bgm > user://bgm（备用）。
func _bgm_roots() -> Array[String]:
	var roots: Array[String] = []
	roots.append(OS.get_executable_path().get_base_dir().path_join("assets").path_join("bgm"))
	roots.append(BGM_DIR_RES)
	roots.append("user://bgm")
	return roots


func _collect_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
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
		var stream := _load_stream(dir_path.path_join(file_name))
		if stream == null:
			continue
		_setup_loop(stream)
		_playlist.append(stream)


## res:// / user:// 直接 load；外部绝对路径按扩展名显式加载。
func _load_stream(path: String) -> AudioStream:
	if path.begins_with("res://") or path.begins_with("user://"):
		var res = load(path)
		return res if res is AudioStream else null
	match path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"flac":
			return AudioStreamWAV.load_from_file(path)
	return null


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
