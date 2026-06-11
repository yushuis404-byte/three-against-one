extends Node2D
## 战争迷雾系统 — 每玩家独立 fog 网格
## float: 0.0=可见, 0.7=无视野(半透明遮罩)

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

var fog_grids: Array = []
var current_player := 0

signal fog_updated()


func _ready() -> void:
	_init_all_fog()


func _init_all_fog() -> void:
	for p in range(3):
		var grid: Array = []
		for y in range(grid_rows):
			var row: Array = []
			for x in range(grid_cols):
				row.append(0.7)
			grid.append(row)
		fog_grids.append(grid)


func _draw() -> void:
	if fog_grids.is_empty():
		return

	var fog: Array = fog_grids[current_player]
	var ts := tile_size - 2.0
	var half := ts / 2.0

	for y in range(grid_rows):
		for x in range(grid_cols):
			var raw: float = fog[y][x]
			if raw <= 0.0:
				continue

			# 3x3 邻域平均 → 边缘自然渐变
			var smoothed := raw
			var count := 1
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and nx < grid_cols and ny >= 0 and ny < grid_rows:
						smoothed += fog[ny][nx]
						count += 1
			smoothed /= count

			var pos := _grid_to_world(x, y)
			var rect := Rect2(pos.x - half, pos.y - half, ts, ts)
			draw_rect(rect, Color(0, 0, 0, smoothed))


# ========== 公共 API ==========

func reveal_tile(player: int, x: int, y: int) -> void:
	if _in_bounds(x, y):
		fog_grids[player][y][x] = 0.0


func reveal_area(player: int, cx: int, cy: int, radius: int) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if _in_bounds(x, y) and _manhattan_dist(x, y, cx, cy) <= radius:
				fog_grids[player][y][x] = 0.0


func explore_area(player: int, cx: int, cy: int, radius: int) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if _in_bounds(x, y) and _manhattan_dist(x, y, cx, cy) <= radius:
				if fog_grids[player][y][x] > 0.7:
					fog_grids[player][y][x] = 0.7


func get_fog(player: int, x: int, y: int) -> float:
	if x < 0 or x >= grid_cols or y < 0 or y >= grid_rows:
		return 1.0
	return fog_grids[player][y][x]


# ========== 工具 ==========

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < grid_cols and y >= 0 and y < grid_rows


func _manhattan_dist(x1: int, y1: int, x2: int, y2: int) -> int:
	return abs(x1 - x2) + abs(y1 - y2)


func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)
