extends Node2D
## 建筑管理器 — 放置、绘制、回合产出、交互
##
## 使用 building_grid[y][x] 记录每格所属 building_id（多格建筑多格同 id）
## 绘制在迷雾之下但领土之上，单位之下

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

var building_grid: Array = []         # [y][x] → building_id 或 -1
var _buildings: Array = []            # Array[Dictionary]
var _next_id := 1
var _selected_id := -1

var _grid_manager: Node = null
var _turn_manager: Node = null
var _territory_mgr: Node = null
var _fog_mgr: Node = null

signal building_hovered(text: String)

const FACTION_COLORS := [
	Color(0.18, 0.60, 0.15),   # 0 精灵绿
	Color(0.80, 0.65, 0.10),   # 1 矮人金
	Color(0.80, 0.25, 0.15),   # 2 兽人红
]
const BUILDING_ALPHA := 0.85
const SELECT_COLOR := Color(1.0, 1.0, 1.0, 0.6)


func _ready() -> void:
	_init_grid()
	_grid_manager = get_parent().get_node("GridManager2D")
	_territory_mgr = get_parent().get_node("TerritoryManager2D")
	_fog_mgr = get_parent().get_node("FogOfWar2D")


func _init_grid() -> void:
	building_grid = []
	for y in range(grid_rows):
		var row: Array = []
		for x in range(grid_cols):
			row.append(-1)
		building_grid.append(row)


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.round_ended.connect(_on_round_ended)


# ========== Building 数据 API ==========

func place_building(data: BuildingData, faction: int, origin: Vector2i) -> bool:
	## 在 origin（建筑左下角原点）放置建筑，成功返回 true
	if not _can_place(data, faction, origin):
		return false

	var bid := _next_id
	_next_id += 1

	var tiles := _get_footprint_tiles(origin, data.footprint)
	for t in tiles:
		building_grid[t.y][t.x] = bid

	_buildings.append({
		"id": bid,
		"data": data,
		"faction": faction,
		"origin": origin,
		"hp": data.hp_max,
	})

	queue_redraw()
	return true


func get_building_at(grid_pos: Vector2i) -> Dictionary:
	if grid_pos.x < 0 or grid_pos.x >= grid_cols or grid_pos.y < 0 or grid_pos.y >= grid_rows:
		return {}
	var bid: int = building_grid[grid_pos.y][grid_pos.x]
	if bid < 0:
		return {}
	for b in _buildings:
		if b["id"] == bid:
			return b
	return {}


func is_tile_occupied(gx: int, gy: int) -> bool:
	if gx < 0 or gx >= grid_cols or gy < 0 or gy >= grid_rows:
		return true  # out of bounds = occupied
	return building_grid[gy][gx] >= 0


# ========== Footprint 工具 ==========

func _get_footprint_tiles(origin: Vector2i, fp: Vector2i) -> Array:
	## 返回建筑原点 + footprint 覆盖的所有 Vector2i 格子
	var result: Array = []
	for dy in range(fp.y):
		for dx in range(fp.x):
			result.append(Vector2i(origin.x + dx, origin.y + dy))
	return result


func _can_place(data: BuildingData, faction: int, origin: Vector2i) -> bool:
	## 校验所有 footprint 格是否满足放置条件
	var tiles := _get_footprint_tiles(origin, data.footprint)
	for t in tiles:
		if t.x < 0 or t.x >= grid_cols or t.y < 0 or t.y >= grid_rows:
			return false
		# 领地检查
		if _territory_mgr:
			var owner: int = _territory_mgr.get_cell_owner(t.x, t.y)
			if owner != faction:
				return false
		# 地形兼容
		if _grid_manager and _grid_manager.has_method("get_terrain_at"):
			var terrain: int = _grid_manager.get_terrain_at(t.x, t.y)
			if not (terrain in data.terrain_compatibility):
				return false
		# 格子未被占用
		if building_grid[t.y][t.x] >= 0:
			return false

	# 阵营上限检查
	if data.max_per_faction < 99:
		var count := 0
		for b in _buildings:
			if b["faction"] == faction and b["data"].name == data.name:
				count += 1
		if count >= data.max_per_faction:
			return false

	return true


func count_buildings(faction: int, name_filter: String = "") -> int:
	var count := 0
	for b in _buildings:
		if b["faction"] != faction:
			continue
		if name_filter.is_empty() or b["data"].name == name_filter:
			count += 1
	return count


# ========== 绘制 ==========

func _draw() -> void:
	if _buildings.is_empty():
		return

	for b in _buildings:
		var data: BuildingData = b["data"]
		var faction: int = b["faction"]
		var origin: Vector2i = b["origin"]
		var fp: Vector2i = data.footprint
		var is_selected: bool = b["id"] == _selected_id

		# 迷雾检查：所有占用格都在迷雾中 → 不绘制
		if _fog_mgr and _fog_mgr.has_method("get_fog"):
			var all_fogged := true
			var tiles := _get_footprint_tiles(origin, fp)
			for t in tiles:
				if _fog_mgr.get_fog(0, t.x, t.y) <= 0.0:
					all_fogged = false
					break
			if all_fogged:
				continue

		var world_origin := _grid_to_world(origin.x, origin.y)
		var w := fp.x * tile_size
		var h := fp.y * tile_size

		# 选中高亮
		if is_selected:
			draw_rect(Rect2(world_origin.x - 2, world_origin.y - 2, w + 4, h + 4),
				SELECT_COLOR, false, 3.0)

		# 建筑底色方块
		var color: Color = FACTION_COLORS[faction]
		color.a = BUILDING_ALPHA
		draw_rect(Rect2(world_origin.x, world_origin.y, w, h), color, true)

		# 描边
		draw_rect(Rect2(world_origin.x, world_origin.y, w, h),
			Color.BLACK, false, 1.5)

		# 建筑名称文字
		var font: Font = ThemeDB.fallback_font
		var fsize := 11
		var label := data.name
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var label_pos := Vector2(
			world_origin.x + w / 2.0 - text_size.x / 2.0,
			world_origin.y + h / 2.0 + fsize / 3.0
		)
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

		# HP 标签（右下角小字）
		var hp_label := "HP:%d" % b["hp"]
		var hp_size := font.get_string_size(hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var hp_pos := Vector2(
			world_origin.x + w - hp_size.x - 2,
			world_origin.y + h - 3
		)
		draw_string(font, hp_pos, hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


# ========== 回合产出 ==========

func _on_round_ended(round_number: int) -> void:
	for b in _buildings:
		var data: BuildingData = b["data"]
		var prod: Dictionary = data.production
		if prod.is_empty():
			continue
		var faction_name := ""
		match b["faction"]:
			0: faction_name = "精灵"
			1: faction_name = "矮人"
			2: faction_name = "兽人"
		var parts: PackedStringArray = []
		for key in prod:
			parts.append("%s +%d" % [key, prod[key]])
		print("[建筑] %s %s: %s" % [faction_name, data.name, ", ".join(parts)])


# ========== 交互 ==========

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cursor := get_global_mouse_position()
		var gpos := _world_to_grid(cursor)
		if gpos.x < 0 or gpos.x >= grid_cols or gpos.y < 0 or gpos.y >= grid_rows:
			_clear_selection()
			return
		var building := get_building_at(gpos)
		if not building.is_empty():
			if _selected_id == building["id"]:
				_clear_selection()
			else:
				_select_building(building["id"])
		else:
			_clear_selection()

	if event is InputEventMouseMotion:
		var cursor := get_global_mouse_position()
		var gpos := _world_to_grid(cursor)
		if gpos.x < 0 or gpos.x >= grid_cols or gpos.y < 0 or gpos.y >= grid_rows:
			building_hovered.emit("")
			return
		var building := get_building_at(gpos)
		if not building.is_empty():
			var data: BuildingData = building["data"]
			var fname := ""
			match building["faction"]:
				0: fname = "精灵"
				1: fname = "矮人"
				2: fname = "兽人"
			building_hovered.emit("%s · %s (HP:%d/%d)" % [fname, data.name, building["hp"], data.hp_max])
		else:
			building_hovered.emit("")


func _select_building(bid: int) -> void:
	_selected_id = bid
	queue_redraw()


func _clear_selection() -> void:
	_selected_id = -1
	queue_redraw()


# ========== 坐标工具 ==========

func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	var gx := int(roundf((world_pos.x - offset.x) / tile_size))
	var gy := int(roundf((world_pos.y - offset.y) / tile_size))
	return Vector2i(gx, gy)
