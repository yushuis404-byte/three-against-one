extends Node2D
## 领土系统 — BFS 连通判定 + 边界线绘制
##
## 与己方主城连通（正交4方向BFS）且已被探索的格子 = 己方领土
## 敌方踏入己方领土则自动显形

signal territory_updated(player: int)

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

# -1=无主/未探索, 0=精灵, 1=矮人, 2=兽人
var owner_grid: Array = []
var town_halls: Array = [[], [], []]  # [player]: Array[Vector2i]
var _turn_manager: Node = null

const BORDER_COLORS := [
	Color(0.18, 0.60, 0.15),   # 0 Elf green
	Color(0.80, 0.65, 0.10),   # 1 Dwarf gold
	Color(0.80, 0.25, 0.15),   # 2 Orc red
]
const BORDER_WIDTH := 2.5
const SHOW_TERRITORY_BORDERS := false


func _ready() -> void:
	_turn_manager = get_parent().get_node_or_null("TurnManager2D")
	if _turn_manager != null and _turn_manager.has_signal("player_turn_started"):
		_turn_manager.player_turn_started.connect(func(_player: int): queue_redraw())
	_init_owner_grid()


func _init_owner_grid() -> void:
	owner_grid = []
	for y in range(grid_rows):
		var row: Array = []
		for x in range(grid_cols):
			row.append(-1)
		owner_grid.append(row)


# ========== 领土计算 ==========

func add_town_hall(player: int, grid_pos: Vector2i) -> void:
	town_halls[player].append(grid_pos)


func remove_town_hall(player: int, grid_pos: Vector2i) -> void:
	town_halls[player].erase(grid_pos)


func recalc_territory(player: int) -> void:
	## BFS 从主城出发，四方向连通已探索的可通行格
	# 清除旧归属
	for y in range(grid_rows):
		for x in range(grid_cols):
			if owner_grid[y][x] == player:
				owner_grid[y][x] = -1

	if town_halls[player].is_empty():
		queue_redraw()
		return

	var fog_mgr = get_parent().get_node("FogOfWar2D")
	var grid_mgr = get_parent().get_node("GridManager2D")
	if not fog_mgr or not grid_mgr:
		return

	var visited := {}
	var queue: Array = []

	for th in town_halls[player]:
		var key := Vector2i(th.x, th.y)
		if not visited.has(key):
			visited[key] = true
			queue.append(th)

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		owner_grid[pos.y][pos.x] = player

		for d in dirs:
			var nx: int = pos.x + d.x
			var ny: int = pos.y + d.y
			if nx < 0 or nx >= grid_cols or ny < 0 or ny >= grid_rows:
				continue
			var nkey := Vector2i(nx, ny)
			if visited.has(nkey):
				continue
			# 仅进入已探索且可通行的格子
			if not fog_mgr.is_explored(player, nx, ny):
				continue
			var terrain: int = grid_mgr.get_terrain_at(nx, ny)
			if not TerrainData.is_passable(terrain):
				continue
			visited[nkey] = true
			queue.append(nkey)

	queue_redraw()
	territory_updated.emit(player)


# ========== 边界线绘制 ==========

func _draw() -> void:
	if not SHOW_TERRITORY_BORDERS:
		return
	if owner_grid.is_empty():
		return

	var viewer: int = _get_current_viewer()
	var half := tile_size / 2.0
	for y in range(grid_rows):
		for x in range(grid_cols):
			var owner: int = owner_grid[y][x]
			if owner < 0:
				continue
			if viewer >= 0 and owner != viewer:
				continue

			var color: Color = BORDER_COLORS[owner]
			var pos := _grid_to_world(x, y)

			# 上边：邻居不同或无主 → 画边界线
			if y <= 0 or owner_grid[y - 1][x] != owner:
				draw_line(
					Vector2(pos.x - half, pos.y - half),
					Vector2(pos.x + half, pos.y - half),
					color, BORDER_WIDTH
				)
			# 下边
			if y >= grid_rows - 1 or owner_grid[y + 1][x] != owner:
				draw_line(
					Vector2(pos.x - half, pos.y + half),
					Vector2(pos.x + half, pos.y + half),
					color, BORDER_WIDTH
				)
			# 左边
			if x <= 0 or owner_grid[y][x - 1] != owner:
				draw_line(
					Vector2(pos.x - half, pos.y - half),
					Vector2(pos.x - half, pos.y + half),
					color, BORDER_WIDTH
				)
			# 右边
			if x >= grid_cols - 1 or owner_grid[y][x + 1] != owner:
				draw_line(
					Vector2(pos.x + half, pos.y - half),
					Vector2(pos.x + half, pos.y + half),
					color, BORDER_WIDTH
				)


# ========== 公共接口 ==========

func get_cell_owner(x: int, y: int) -> int:
	if x < 0 or x >= grid_cols or y < 0 or y >= grid_rows:
		return -1
	return owner_grid[y][x]


func is_territory(player: int, x: int, y: int) -> bool:
	return get_cell_owner(x, y) == player


func _get_current_viewer() -> int:
	if _turn_manager == null:
		return -1
	return int(_turn_manager.current_player)


# ========== 工具 ==========

func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)
