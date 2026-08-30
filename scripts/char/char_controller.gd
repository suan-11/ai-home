extends CharacterBody2D
## Phase 1 角色控制器。
## 在网格上逐格移动，使用 GridPathfinder 找路，并播放 idle/walk 动画。

signal state_changed(state_name: String)
signal interaction_triggered(interaction_name: String)

const SPEED := 80.0  # 像素/秒
const CELL_SIZE := 16
const CELL_CENTER_OFFSET := Vector2(8, 8)
const CHAR_ID := "char_03"
const CHAR_SPRITE_PATH := "res://assets/chars/%s/sprites" % CHAR_ID

var grid_size: Vector2i = Vector2i(16, 12)
var grid_origin: Vector2 = Vector2.ZERO
var current_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i(-1, -1)

var _blocked_cells: Dictionary = {}

var _pathfinder := GridPathfinder.new()
var _state_machine := CharacterStateMachine.new()
var _path: Array = []
var _sprite: AnimatedSprite2D
var _action_tween: Tween


func _ready() -> void:
	_sprite = $AnimatedSprite2D
	_setup_animations()
	_sprite.scale = Vector2(0.25, 0.25)
	current_cell = _pixel_to_cell(position)
	_sprite.play("idle")


func set_blocked_cells(blocked: Dictionary) -> void:
	_blocked_cells = blocked


func trigger_interaction(interaction_name: String) -> void:
	## 预留交互接口：后续在这里实现坐下、睡觉、工作等具体行为。
	_path.clear()
	_state_machine.change_state(CharacterStateMachine.State.IDLE)
	_sprite.play("idle")
	interaction_triggered.emit(interaction_name)
	print("[Interaction] ", interaction_name)


func stop_movement() -> void:
	## 停下当前寻路，回到待机（用于手机指令中的情绪动作）。
	_path.clear()
	if _state_machine.is_state(CharacterStateMachine.State.WALK_TO):
		_state_machine.change_state(CharacterStateMachine.State.IDLE)
		_sprite.play("idle")
		state_changed.emit("idle")


func play_action(action_name: String) -> void:
	## 轻量动作动画：wave / hop / sad；不打断物理移动循环。
	if not is_inside_tree():
		return
	_kill_action_tween()
	match action_name:
		"wave":
			_action_tween = create_tween().set_loops(3)
			_action_tween.tween_property(_sprite, "rotation", deg_to_rad(-14.0), 0.08)
			_action_tween.tween_property(_sprite, "rotation", deg_to_rad(14.0), 0.16)
			_action_tween.tween_property(_sprite, "rotation", 0.0, 0.08)
			_action_tween.finished.connect(func() -> void: _sprite.rotation = 0.0)
		"hop":
			_action_tween = create_tween().set_loops(2)
			_action_tween.tween_property(_sprite, "position:y", -6.0, 0.09) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_action_tween.tween_property(_sprite, "position:y", 0.0, 0.09) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_action_tween.finished.connect(func() -> void: _sprite.position = Vector2.ZERO)
		"sad":
			_action_tween = create_tween()
			_action_tween.tween_property(_sprite, "rotation", deg_to_rad(8.0), 0.2)
			_action_tween.tween_interval(0.5)
			_action_tween.tween_property(_sprite, "rotation", 0.0, 0.15)
			_action_tween.finished.connect(func() -> void: _sprite.rotation = 0.0)
		_:
			return


func _kill_action_tween() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
		_action_tween = null
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0


func set_grid(origin: Vector2, size: Vector2i) -> void:
	grid_origin = origin
	grid_size = size
	current_cell = _pixel_to_cell(position)
	_sprite.play("idle")


func move_to_cell(cell: Vector2i) -> void:
	cell = _clamp_to_grid(cell)
	target_cell = cell
	if cell == current_cell:
		target_cell = Vector2i(-1, -1)
		return

	var path := _pathfinder.find_path(current_cell, cell, grid_size, _blocked_cells)
	if path.is_empty():
		_state_machine.change_state(CharacterStateMachine.State.IDLE)
		_sprite.play("idle")
		state_changed.emit("idle")
		return

	# 路径首格通常是当前位置，移除后从下一格开始走
	if not path.is_empty() and path[0] == current_cell:
		path.remove_at(0)

	if path.is_empty():
		_state_machine.change_state(CharacterStateMachine.State.IDLE)
		_sprite.play("idle")
		state_changed.emit("idle")
		return

	_path = path
	_state_machine.change_state(CharacterStateMachine.State.WALK_TO)
	_sprite.play("walk")
	state_changed.emit("walk")


func get_current_path() -> Array:
	return _path


func _physics_process(delta: float) -> void:
	if not _state_machine.is_state(CharacterStateMachine.State.WALK_TO):
		return
	if _path.is_empty():
		_state_machine.change_state(CharacterStateMachine.State.IDLE)
		_sprite.play("idle")
		state_changed.emit("idle")
		return

	var next_cell: Vector2i = _path[0]
	var target_pos: Vector2 = _cell_to_pixel(next_cell)
	position = position.move_toward(target_pos, SPEED * delta)

	if position.distance_to(target_pos) < 0.01:
		position = target_pos
		current_cell = next_cell
		_path.remove_at(0)

		if _path.is_empty():
			_state_machine.change_state(CharacterStateMachine.State.IDLE)
			_sprite.play("idle")
			state_changed.emit("idle")


func _setup_animations() -> void:
	var frames := SpriteFrames.new()

	var idle_0: Texture2D = load(CHAR_SPRITE_PATH + "/idle_0.png")
	var idle_1: Texture2D = load(CHAR_SPRITE_PATH + "/idle_1.png")
	frames.add_animation("idle")
	frames.add_frame("idle", idle_0)
	frames.add_frame("idle", idle_1)
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_loop("idle", true)

	var walk_0: Texture2D = load(CHAR_SPRITE_PATH + "/walk_0.png")
	var walk_1: Texture2D = load(CHAR_SPRITE_PATH + "/walk_1.png")
	var walk_2: Texture2D = load(CHAR_SPRITE_PATH + "/walk_2.png")
	var walk_3: Texture2D = load(CHAR_SPRITE_PATH + "/walk_3.png")
	frames.add_animation("walk")
	frames.add_frame("walk", walk_0)
	frames.add_frame("walk", walk_1)
	frames.add_frame("walk", walk_2)
	frames.add_frame("walk", walk_3)
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)

	_sprite.sprite_frames = frames


func _cell_to_pixel(cell: Vector2i) -> Vector2:
	return grid_origin + Vector2(cell.x, cell.y) * CELL_SIZE + CELL_CENTER_OFFSET


func _pixel_to_cell(pos: Vector2) -> Vector2i:
	var local := (pos - grid_origin) / CELL_SIZE
	return Vector2i(floori(local.x), floori(local.y))


func _clamp_to_grid(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, grid_size.x - 1),
		clampi(cell.y, 0, grid_size.y - 1)
	)
