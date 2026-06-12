extends Node2D
## 战争迷雾系统 — 每玩家独立 fog 网格
## float: 0.0=已探索, 0.7=未探索(半透明遮罩)
##
## 首次探索时触发 0.3s 渐隐动画，完成后发射 fog_updated 信号

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

var fog_grids: Array = []
var current_player := 0

signal fog_updated(player: int)

var _turn_manager: Node = null


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.player_turn_started.connect(_on_player_turn_started)


func _on_player_turn_started(player: int) -> void:
	current_player = player
	queue_redraw()

# 渐隐动画追踪 [player]{Vector2i: elapsed}
var _fading_out: Array = [{}, {}, {}]
const FADE_DURATION := 0.3


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


func _process(delta: float) -> void:
	var changed_players: Dictionary = {}
	for player in range(3):
		var fading: Dictionary = _fading_out[player]
		var still_fading: Dictionary = {}
		for pos_key in fading:
			var elapsed: float = fading[pos_key] + delta
			var t := clampf(elapsed / FADE_DURATION, 0.0, 1.0)
			var val := 0.7 * (1.0 - t)
			var pos: Vector2i = pos_key
			fog_grids[player][pos.y][pos.x] = val
			if t >= 1.0:
				fog_grids[player][pos.y][pos.x] = 0.0
				changed_players[player] = true
			else:
				still_fading[pos_key] = elapsed
		_fading_out[player] = still_fading

	if not changed_players.is_empty():
		queue_redraw()
		for p in changed_players:
			fog_updated.emit(p)

	# 无活动动画时停止 _process
	var any_active := false
	for p in range(3):
		if not _fading_out[p].is_empty():
			any_active = true
			break
	if not any_active:
		set_process(false)


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

func reveal_area(player: int, cx: int, cy: int, radius: int) -> void:
	## 揭示区域并触发渐隐动画
	var has_new := false
	var fading: Dictionary = _fading_out[player]
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if _in_bounds(x, y) and _manhattan_dist(x, y, cx, cy) <= radius:
				if fog_grids[player][y][x] >= 0.7 and not fading.has(Vector2i(x, y)):
					fading[Vector2i(x, y)] = 0.0
					has_new = true
	if has_new:
		set_process(true)


func reveal_tile(player: int, x: int, y: int) -> void:
	## 揭示单个地块（无动画）
	if _in_bounds(x, y):
		fog_grids[player][y][x] = 0.0


func reveal_area_immediate(player: int, cx: int, cy: int, radius: int) -> void:
	## 揭示区域但不触发动画（用于初始设置）
	var changed := false
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if _in_bounds(x, y) and _manhattan_dist(x, y, cx, cy) <= radius:
				if fog_grids[player][y][x] >= 0.7:
					fog_grids[player][y][x] = 0.0
					changed = true
	if changed:
		queue_redraw()


func explore_area(player: int, cx: int, cy: int, radius: int) -> void:
	## 依现有设计：无未探索态，故本函数仅保留接口
	pass


func is_explored(player: int, x: int, y: int) -> bool:
	## 供 TerritoryManager 查询该格是否已被探索
	if x < 0 or x >= grid_cols or y < 0 or y >= grid_rows:
		return false
	return fog_grids[player][y][x] <= 0.0


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
