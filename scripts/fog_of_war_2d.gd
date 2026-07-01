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
var _grid_manager: Node = null
var _unit_manager: Node = null
var _magic_fog_zones: Array[Dictionary] = []
var _next_magic_fog_zone_id := 1
var _fog_image: Image = null
var _fog_texture: ImageTexture = null

const MAGIC_FOG_ALPHA := 0.7
const MAGIC_FOG_OWNER_FILL := Color(0.2, 0.7, 1.0, 0.14)
const MAGIC_FOG_OWNER_BORDER := Color(0.55, 0.9, 1.0, 0.78)
const MAGIC_FOG_OWNER_CENTER := Color(0.45, 0.95, 1.0, 0.9)


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.player_turn_started.connect(_on_player_turn_started)
		if tm.has_signal("view_player_changed"):
			tm.view_player_changed.connect(_on_view_player_changed)


func _on_player_turn_started(player: int) -> void:
	current_player = _get_view_player(player)
	queue_redraw()


func _on_view_player_changed(player: int) -> void:
	current_player = player
	queue_redraw()


func _get_view_player(fallback: int) -> int:
	if _turn_manager != null:
		var value: int = int(_turn_manager.get("view_player"))
		if value >= 0 and value < fog_grids.size():
			return value
	return fallback

# 渐隐动画追踪 [player]{Vector2i: elapsed}
var _fading_out: Array = [{}, {}, {}]
const FADE_DURATION := 0.3


func _ready() -> void:
	_grid_manager = get_parent().get_node_or_null("GridManager2D")
	_unit_manager = get_parent().get_node_or_null("UnitManager2D")
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
	var animation_updated := false
	for player in range(3):
		var fading: Dictionary = _fading_out[player]
		var still_fading: Dictionary = {}
		for pos_key in fading:
			animation_updated = true
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

	if animation_updated:
		queue_redraw()
	if not changed_players.is_empty():
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

	_update_fog_texture()
	if _fog_texture == null:
		return

	var top_left := _grid_to_world(0, 0) - Vector2(tile_size * 0.5, tile_size * 0.5)
	var rect := Rect2(top_left, Vector2(float(grid_cols) * tile_size, float(grid_rows) * tile_size))
	draw_texture_rect(_fog_texture, rect, false)
	_draw_magic_fog_owner_markers()


func _update_fog_texture() -> void:
	if _fog_image == null or _fog_image.get_width() != grid_cols or _fog_image.get_height() != grid_rows:
		_fog_image = Image.create(grid_cols, grid_rows, false, Image.FORMAT_RGBA8)

	for y in range(grid_rows):
		for x in range(grid_cols):
			if _is_ocean_tile(x, y):
				_fog_image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var raw: float = _get_effective_fog(current_player, x, y)
			if raw <= 0.0:
				_fog_image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			# 3x3 邻域平均 → 边缘自然渐变
			var smoothed := raw
			var count := 1
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and nx < grid_cols and ny >= 0 and ny < grid_rows:
						smoothed += _get_effective_fog(current_player, nx, ny)
						count += 1
			smoothed /= count

			_fog_image.set_pixel(x, y, Color(0, 0, 0, smoothed))

	if _fog_texture == null:
		_fog_texture = ImageTexture.create_from_image(_fog_image)
	else:
		_fog_texture.update(_fog_image)


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


func conceal_area(player: int, cx: int, cy: int, radius: int) -> void:
	## 将指定玩家已探索区域重新遮蔽为迷雾。
	var changed := false
	var fading: Dictionary = _fading_out[player]
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if _in_bounds(x, y) and _manhattan_dist(x, y, cx, cy) <= radius:
				var pos := Vector2i(x, y)
				if fading.has(pos):
					fading.erase(pos)
				if fog_grids[player][y][x] < 0.7:
					fog_grids[player][y][x] = 0.7
					changed = true
	if changed:
		queue_redraw()
		fog_updated.emit(player)


func add_magic_fog(owner: int, cx: int, cy: int, radius: int, duration_rounds: int) -> void:
	if not _in_bounds(cx, cy):
		return
	var zone: Dictionary = {
		"id": _next_magic_fog_zone_id,
		"owner": owner,
		"center": Vector2i(cx, cy),
		"radius": maxi(0, radius),
		"remaining_rounds": maxi(1, duration_rounds),
	}
	_next_magic_fog_zone_id += 1
	_magic_fog_zones.append(zone)
	queue_redraw()
	_emit_magic_fog_visibility_changed()


func tick_magic_fog_round() -> void:
	if _magic_fog_zones.is_empty():
		return
	var kept: Array[Dictionary] = []
	var expired := false
	for zone_variant in _magic_fog_zones:
		var zone: Dictionary = zone_variant
		var remaining: int = int(zone.get("remaining_rounds", 0)) - 1
		if remaining > 0:
			zone["remaining_rounds"] = remaining
			kept.append(zone)
		else:
			expired = true
	_magic_fog_zones = kept
	queue_redraw()
	if expired:
		_emit_magic_fog_visibility_changed()


func has_magic_fog_at(owner: int, x: int, y: int) -> bool:
	for zone_variant in _magic_fog_zones:
		var zone: Dictionary = zone_variant
		if int(zone.get("owner", -1)) == owner and _is_tile_in_magic_fog_zone(zone, x, y):
			return true
	return false


func explore_area(player: int, cx: int, cy: int, radius: int) -> void:
	## 依现有设计：无未探索态，故本函数仅保留接口
	pass


func is_explored(player: int, x: int, y: int) -> bool:
	## 供 TerritoryManager 查询该格是否已被探索
	if x < 0 or x >= grid_cols or y < 0 or y >= grid_rows:
		return false
	return _get_effective_fog(player, x, y) <= 0.0


func get_fog(player: int, x: int, y: int) -> float:
	if x < 0 or x >= grid_cols or y < 0 or y >= grid_rows:
		return 1.0
	return _get_effective_fog(player, x, y)


# ========== 工具 ==========

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < grid_cols and y >= 0 and y < grid_rows


func _manhattan_dist(x1: int, y1: int, x2: int, y2: int) -> int:
	return abs(x1 - x2) + abs(y1 - y2)


func _get_effective_fog(player: int, x: int, y: int) -> float:
	var base_fog: float = float(fog_grids[player][y][x])
	if _is_magic_fog_blocking(player, x, y):
		return maxf(base_fog, MAGIC_FOG_ALPHA)
	return base_fog


func _is_magic_fog_blocking(player: int, x: int, y: int) -> bool:
	for zone_variant in _magic_fog_zones:
		var zone: Dictionary = zone_variant
		if int(zone.get("owner", -1)) == player:
			continue
		if not _is_tile_in_magic_fog_zone(zone, x, y):
			continue
		if _player_has_inside_zone_vision(player, zone, x, y):
			continue
		return true
	return false


func _player_has_inside_zone_vision(player: int, zone: Dictionary, x: int, y: int) -> bool:
	if _unit_manager == null and is_inside_tree():
		_unit_manager = get_parent().get_node_or_null("UnitManager2D")
	if _unit_manager == null or not _unit_manager.has_method("get_all_units"):
		return false
	var units: Array = _unit_manager.call("get_all_units")
	for unit_variant in units:
		var unit: Dictionary = unit_variant
		if int(unit.get("faction", -1)) != player:
			continue
		var pos: Vector2i = unit.get("grid_pos", Vector2i(-1, -1))
		if pos.x < 0 or not _is_tile_in_magic_fog_zone(zone, pos.x, pos.y):
			continue
		var vision: int = _get_unit_vision_for_magic_fog(unit)
		if _manhattan_dist(pos.x, pos.y, x, y) <= vision:
			return true
	return false


func _get_unit_vision_for_magic_fog(unit: Dictionary) -> int:
	if _unit_manager != null and _unit_manager.has_method("get_unit_vision_for_fog"):
		return maxi(0, int(_unit_manager.call("get_unit_vision_for_fog", unit)))
	if unit.has("data"):
		var data: UnitData = unit["data"]
		return maxi(0, data.vision)
	return 1


func _is_tile_in_magic_fog_zone(zone: Dictionary, x: int, y: int) -> bool:
	var center: Vector2i = zone.get("center", Vector2i(-1, -1))
	var radius: int = int(zone.get("radius", 0))
	return _in_bounds(x, y) and _manhattan_dist(x, y, center.x, center.y) <= radius


func _draw_magic_fog_owner_markers() -> void:
	if _magic_fog_zones.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var label_size := 13
	var ts := tile_size + 1.0
	var half := ts / 2.0
	for zone_variant in _magic_fog_zones:
		var zone: Dictionary = zone_variant
		if int(zone.get("owner", -1)) != current_player:
			continue
		var center: Vector2i = zone.get("center", Vector2i(-1, -1))
		var radius: int = int(zone.get("radius", 0))
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if not _is_tile_in_magic_fog_zone(zone, x, y) or _is_ocean_tile(x, y):
					continue
				var pos := _grid_to_world(x, y)
				var rect := Rect2(pos.x - half, pos.y - half, ts, ts)
				draw_rect(rect.grow(-3.0), MAGIC_FOG_OWNER_FILL, true)
				draw_rect(rect.grow(-3.0), MAGIC_FOG_OWNER_BORDER, false, 1.2)
		if not _in_bounds(center.x, center.y):
			continue
		var center_world := _grid_to_world(center.x, center.y)
		draw_circle(center_world, 6.0, MAGIC_FOG_OWNER_CENTER)
		var label := "%d回合" % int(zone.get("remaining_rounds", 0))
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size)
		draw_string(font, center_world + Vector2(-text_size.x / 2.0, -12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, MAGIC_FOG_OWNER_BORDER)


func _emit_magic_fog_visibility_changed() -> void:
	for player in range(3):
		fog_updated.emit(player)


func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)


func _is_ocean_tile(x: int, y: int) -> bool:
	if not _grid_manager or not _grid_manager.has_method("get_terrain_at"):
		return false
	return int(_grid_manager.get_terrain_at(x, y)) == TerrainData.Terrain.WATER
