extends Node2D
## 资源点管理器 — 独立于地形系统
## 维护 resource_grid，负责放置、绘制菱形、悬浮提示

# ========== 网格配置（由外部注入） ==========
var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var land_offset_x := 22

var grid_center := Vector2(49.5, 27.5)
var resource_grid: Array = []
var _last_hovered: Vector2i = Vector2i(-1, -1)
var _turn_manager: Node = null

signal resource_hovered(text: String)


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.player_turn_started.connect(_on_player_turn_started)


func _on_player_turn_started(_player: int) -> void:
	queue_redraw()


# ========== 资源类型枚举 ==========

enum ResourceType {
	NONE,
	GOLD_MINE,
	ANCIENT_FOREST,
	QUARRY,
	FERTILE_PLAIN,
	IRON_MINE,
	MAGIC_NODE,
	ANCIENT_TREE,
	RUNE_STONE,
	ABANDONED_POST,
	STAR_CRYSTAL,
	WORLD_TREE_ROOT,
	DRAGON_CRYSTAL,
	HOT_SPRING,
	ANCIENT_RELIC,
}

# ========== 资源定义表 ==========
# [type, name, total, color, {zone_tag_int: count}, [compatible_terrains...]]
# zone_tag_key uses raw int (ZoneTag enum from grid_manager_2d.gd, not class_name)
# terrain uses TerrainData.Terrain which IS a global class_name
const RESOURCE_DEFS: Array = [
	[ResourceType.GOLD_MINE, "金矿脉", 18, Color(1.0, 0.84, 0.0),
	 { 7: 3, 8: 3, 9: 3, 12: 3, 11: 1, 10: 1, 4: 4 },
	 [TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF,
	  TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.RUINS]],
	[ResourceType.ANCIENT_FOREST, "古树林", 16, Color(0.13, 0.55, 0.13),
	 { 7: 6, 8: 4, 10: 3, 9: 3 },
	 [TerrainData.Terrain.FOREST_ELF]],
	[ResourceType.QUARRY, "石场", 16, Color(0.55, 0.50, 0.45),
	 { 8: 6, 12: 3, 4: 3, 11: 2, 9: 2 },
	 [TerrainData.Terrain.MOUNTAIN_DWARF]],
	[ResourceType.FERTILE_PLAIN, "肥沃平原", 16, Color(0.45, 0.75, 0.30),
	 { 8: 5, 9: 5, 10: 2, 12: 2, 4: 2 },
	 [TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.WASTELAND_ORC,
	  TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF]],
	[ResourceType.IRON_MINE, "铁矿脉", 14, Color(0.65, 0.65, 0.65),
	 { 8: 5, 11: 3, 9: 3, 4: 2, 12: 1 },
	 [TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.PLAIN_DWARF]],
	[ResourceType.MAGIC_NODE, "魔力节点", 14, Color(0.60, 0.20, 0.80),
	 { 7: 5, 10: 3, 4: 3, 11: 2, 8: 1 },
	 [TerrainData.Terrain.RUINS, TerrainData.Terrain.FOREST_ELF]],
	[ResourceType.ANCIENT_TREE, "古木巨树", 14, Color(0.05, 0.35, 0.05),
	 { 7: 5, 10: 4, 4: 3, 8: 1, 9: 1 },
	 [TerrainData.Terrain.FOREST_ELF]],
	[ResourceType.RUNE_STONE, "远古符文碑", 14, Color(0.00, 0.55, 0.55),
	 { 11: 3, 7: 3, 4: 3, 8: 3, 9: 2 },
	 [TerrainData.Terrain.RUINS, TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.MOUNTAIN_DWARF]],
	[ResourceType.ABANDONED_POST, "废弃商站", 6, Color(0.55, 0.27, 0.07),
	 { 4: 2, 10: 1, 11: 1, 12: 1, 7: 1 },
	 [TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
	  TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.GLADE_ELF]],
	[ResourceType.STAR_CRYSTAL, "星晶矿床", 8, Color(0.20, 0.40, 0.90),
	 { 4: 4, 11: 2, 7: 1, 8: 1 },
	 [TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.RUINS]],
	[ResourceType.WORLD_TREE_ROOT, "世界树根脉", 8, Color(0.00, 0.50, 0.40),
	 { 7: 6, 10: 1, 8: 1 },
	 [TerrainData.Terrain.FOREST_ELF, TerrainData.Terrain.GLADE_ELF, TerrainData.Terrain.RUINS]],
	[ResourceType.DRAGON_CRYSTAL, "龙晶火山口", 8, Color(0.85, 0.10, 0.70),
	 { 9: 5, 12: 3 },
	 [TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.WASTELAND_ORC,
	  TerrainData.Terrain.SWAMP_ORC, TerrainData.Terrain.RUINS]],
	[ResourceType.HOT_SPRING, "地热泉眼", 3, Color(1.0, 0.45, 0.05),
	 { 4: 3 },
	 [TerrainData.Terrain.PLAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
	  TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.CORRIDOR,
	  TerrainData.Terrain.GLADE_ELF, TerrainData.Terrain.MOUNTAIN_DWARF]],
	[ResourceType.ANCIENT_RELIC, "古龙遗迹", 2, Color(0.80, 0.15, 0.15),
	 { 4: 2 },
	 [TerrainData.Terrain.RUINS, TerrainData.Terrain.PLAIN_DWARF,
	  TerrainData.Terrain.MOUNTAIN_DWARF, TerrainData.Terrain.FOREST_ELF,
	  TerrainData.Terrain.WASTELAND_ORC, TerrainData.Terrain.CORRIDOR]],
]


func configure(cols: int, rows: int, tile: float, offset: int, gcenter: Vector2) -> void:
	grid_cols = cols
	grid_rows = rows
	tile_size = tile
	land_offset_x = offset
	grid_center = gcenter


func init_grid(size: int) -> void:
	resource_grid = []
	for y in range(size):
		var row: Array = []
		for x in range(size):
			row.append(ResourceType.NONE)
		resource_grid.append(row)


func expand_grid(cols: int, rows: int, offset_x: int) -> void:
	var expanded: Array = []
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			row.append(ResourceType.NONE)
		expanded.append(row)

	for y in range(resource_grid.size()):
		for x in range(resource_grid[y].size()):
			expanded[y][x + offset_x] = resource_grid[y][x]

	resource_grid = expanded
	grid_cols = cols
	grid_rows = rows
	land_offset_x = offset_x


# ========== 资源放置 ==========

func place_resources(zone_grid: Array, terrain_grid: Array, grid_size: int) -> void:
	for def in RESOURCE_DEFS:
		var rtype: int = def[0]
		var zone_counts: Dictionary = def[4]
		var compat_terrains: Array = def[5]

		for zone_tag in zone_counts:
			var needed: int = zone_counts[zone_tag]
			var candidates: Array = []

			for y in range(grid_size):
				for x in range(grid_size):
					if zone_grid[y][x] != zone_tag:
						continue
					if resource_grid[y][x] != ResourceType.NONE:
						continue
					if compat_terrains.size() > 0 and not (terrain_grid[y][x] in compat_terrains):
						continue
					candidates.append(Vector2i(x, y))

			# Deterministic shuffle
			for i in range(candidates.size() - 1, 0, -1):
				var shuffle_seed := int(rtype * 100 + zone_tag * 10 + i)
				var j := int(_simple_hash(candidates[i].x, candidates[i].y, shuffle_seed) * (i + 1))
				var temp: Vector2i = candidates[i]
				candidates[i] = candidates[j]
				candidates[j] = temp

			var placed := 0
			for cell in candidates:
				if placed >= needed:
					break
				var cx: int = cell.x
				var cy: int = cell.y
				if resource_grid[cy][cx] == ResourceType.NONE:
					resource_grid[cy][cx] = rtype
					placed += 1

			if placed < needed:
				print("[资源] 警告: %s 在区域 %d 中仅放置 %d/%d" % [def[1], zone_tag, placed, needed])


# ========== 哈希（与地形系统共享算法） ==========

func _simple_hash(x: int, y: int, seed: int = 12345) -> float:
	var val := (x * 374761393 + y * 668265263 + seed) & 0x7FFFFFFF
	val = ((val ^ (val >> 13)) * 1274126177) & 0x7FFFFFFF
	return float(val % 1000) / 1000.0


# ========== 菱形绘制 ==========

func _draw() -> void:
	if resource_grid.is_empty():
		return

	const MARKER_SIZE := 5.0
	for y in range(grid_rows):
		for x in range(grid_cols):
			var rt: int = resource_grid[y][x]
			if rt == ResourceType.NONE:
				continue
			# 迷雾遮挡 → 不画资源菱形
			var fog_mgr = get_parent().get_node("FogOfWar2D")
			var viewer: int = _turn_manager.current_player if _turn_manager else 0
			if fog_mgr and fog_mgr.get_fog(viewer, x, y) > 0.0:
				continue
			var color: Color = RESOURCE_DEFS[rt - 1][3]
			color.a = 0.85
			var pos := _grid_to_world(x, y)
			var rect := Rect2(pos.x - MARKER_SIZE, pos.y - MARKER_SIZE, MARKER_SIZE * 2.0, MARKER_SIZE * 2.0)
			draw_rect(rect, color)
			var inner := Rect2(pos.x - MARKER_SIZE * 0.4, pos.y - MARKER_SIZE * 0.4, MARKER_SIZE * 0.8, MARKER_SIZE * 0.8)
			draw_rect(inner, Color(1.0, 1.0, 1.0, 0.3))


# ========== 坐标工具 ==========

func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	var gx := int(roundf((world_pos.x - offset.x) / tile_size))
	var gy := int(roundf((world_pos.y - offset.y) / tile_size))
	return Vector2i(gx, gy)


# ========== 悬浮交互 ==========

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cursor_pos := get_global_mouse_position()
		var grid_pos := _world_to_grid(cursor_pos)
		if grid_pos.x < 0 or grid_pos.x >= grid_cols or grid_pos.y < 0 or grid_pos.y >= grid_rows:
			if _last_hovered != Vector2i(-1, -1):
				_last_hovered = Vector2i(-1, -1)
				resource_hovered.emit("")
			return
		if grid_pos == _last_hovered:
			return
		_last_hovered = grid_pos
		var rt: int = resource_grid[grid_pos.y][grid_pos.x]
		if rt != ResourceType.NONE:
			var name: String = RESOURCE_DEFS[rt - 1][1]
			resource_hovered.emit(name)
		else:
			resource_hovered.emit("")


# ========== 公共接口 ==========

func get_resource_type_at(x: int, y: int) -> int:
	if x < 0 or x >= grid_cols or y < 0 or y >= grid_rows:
		return ResourceType.NONE
	return resource_grid[y][x]


func get_stats() -> Dictionary:
	var counts: Dictionary = {}
	var total := 0
	for y in range(grid_rows):
		for x in range(grid_cols):
			var rt: int = resource_grid[y][x]
			if rt != ResourceType.NONE:
				counts[rt] = counts.get(rt, 0) + 1
				total += 1
	return { "counts": counts, "total": total }
