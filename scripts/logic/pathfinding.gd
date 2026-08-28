class_name GridPathfinder
extends RefCounted
## 网格 A* 寻路（Phase 1 基础版）。
## 支持 4 方向移动，可通过 blocked 字典阻挡格子。

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


func find_path(
	start: Vector2i,
	goal: Vector2i,
	grid_size: Vector2i,
	blocked: Dictionary = {}
) -> Array:
	if start == goal:
		return [start]
	if not _inside(start, grid_size) or not _inside(goal, grid_size):
		return []

	var open: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: _heuristic(start, goal)}

	while not open.is_empty():
		var current: Vector2i = _lowest_f(open, f_score)
		open.erase(current)

		if current == goal:
			return _reconstruct(came_from, current)

		for dir in DIRS:
			var neighbor: Vector2i = current + dir
			if not _inside(neighbor, grid_size):
				continue
			if blocked.has(neighbor):
				continue

			var tentative_g: int = g_score[current] + 1
			if tentative_g < g_score.get(neighbor, 1 << 30):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, goal)
				if not open.has(neighbor):
					open.append(neighbor)

	return []


func _lowest_f(open: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var best: Vector2i = open[0]
	var best_score: int = f_score.get(best, 1 << 30)
	for cell in open:
		var score: int = f_score.get(cell, 1 << 30)
		if score < best_score:
			best = cell
			best_score = score
	return best


func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _inside(cell: Vector2i, grid_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func _reconstruct(came_from: Dictionary, current: Vector2i) -> Array:
	var path: Array = [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path
