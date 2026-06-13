extends Node2D
## 单位管理器 — 放置、绘制、选择、移动
##
## 单位绘制在迷雾之下（原型简化），阵营色圆圈 + 中文名 + HP

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

var _units: Array = []       # Array[Dictionary]
var _next_id := 1
var _selected_id := -1
var _reachable_tiles: Array = []  # 当前选中单位的可达格列表

var _turn_manager: Node = null
var _grid_manager: Node = null

const FACTION_COLORS := [
	Color(0.18, 0.60, 0.15),   # 0 精灵绿
	Color(0.80, 0.65, 0.10),   # 1 矮人金
	Color(0.80, 0.25, 0.15),   # 2 兽人红
]
const SELECT_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const REACHABLE_COLOR := Color(1.0, 1.0, 1.0, 0.25)
const UNIT_RADIUS := 8.0


func _ready() -> void:
	_grid_manager = get_parent().get_node("GridManager2D")


func set_turn_manager(tm: Node) -> void:
	_turn_manager = tm
	if tm:
		tm.player_turn_started.connect(_on_player_turn_started)
		tm.player_turn_ended.connect(_on_player_turn_ended)


# ========== 单位管理 ==========

func place_initial_units() -> void:
	## 每阵营初始：1工人 + 1斥候 + 1守卫
	var spawns := [
		{ "player": 0, "pos": Vector2i(35, 13), "name_offset": -1 },
		{ "player": 1, "pos": Vector2i(35, 43), "name_offset": -2 },
		{ "player": 2, "pos": Vector2i(62, 35), "name_offset": -3 },
	]
	var fog_mgr = get_parent().get_node("FogOfWar2D")
	for s in spawns:
		var p: int = s["player"]
		var pos: Vector2i = s["pos"]
		var offset: int = s["name_offset"]
		_add_unit(p, UnitData.worker(), Vector2i(pos.x + offset, pos.y))
		_add_unit(p, UnitData.scout(), Vector2i(pos.x + offset + 1, pos.y))
		_add_unit(p, UnitData.guard(), Vector2i(pos.x + offset + 2, pos.y))

		# 初始放置时揭示视野
		for u in _units:
			if u["faction"] != p:
				continue
			var upos: Vector2i = u["grid_pos"]
			fog_mgr.reveal_area(p, upos.x, upos.y, u["data"].vision)


func _add_unit(faction: int, data: UnitData, grid_pos: Vector2i) -> int:
	var uid := _next_id
	_next_id += 1
	_units.append({
		"id": uid,
		"data": data,
		"faction": faction,
		"grid_pos": grid_pos,
		"hp": data.hp_max,
		"has_moved": false,
		"has_attacked": false,
	})
	return uid


func get_unit_at(grid_pos: Vector2i) -> Dictionary:
	for u in _units:
		if u["grid_pos"] == grid_pos:
			return u
	return {}


func get_player_units(player: int) -> Array:
	var result: Array = []
	for u in _units:
		if u["faction"] == player:
			result.append(u)
	return result


# ========== 绘制 ==========

func _draw() -> void:
	if _units.is_empty():
		return

	# 绘制可达格高亮
	for t in _reachable_tiles:
		var pos2 := _grid_to_world(t.x, t.y)
		draw_circle(pos2, UNIT_RADIUS * 1.5, REACHABLE_COLOR)

	for u in _units:
		var pos: Vector2i = u["grid_pos"]
		var world_pos := _grid_to_world(pos.x, pos.y)
		var faction: int = u["faction"]
		var data: UnitData = u["data"]
		var hp: int = u["hp"]
		var uid: int = u["id"]
		var is_selected := uid == _selected_id

		# 选中高亮
		if is_selected:
			draw_circle(world_pos, UNIT_RADIUS + 3.0, SELECT_COLOR)

		# 阵营色填充圆
		draw_circle(world_pos, UNIT_RADIUS, FACTION_COLORS[faction])

		# 黑色描边
		draw_arc(world_pos, UNIT_RADIUS, 0, TAU, 16, Color.BLACK, 1.5)

		# 中文名称（圆上方）
		var font: Font = ThemeDB.fallback_font
		var fsize := 11
		var label := data.unit_name
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var name_pos := Vector2(world_pos.x - text_size.x / 2.0, world_pos.y - UNIT_RADIUS - 4.0)
		draw_string(font, name_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

		# HP 数字（圆下方）
		var hp_label := str(hp)
		var hp_size := font.get_string_size(hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var hp_pos := Vector2(world_pos.x - hp_size.x / 2.0, world_pos.y + UNIT_RADIUS + 14.0)
		draw_string(font, hp_pos, hp_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)


# ========== 交互 ==========

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var cursor := get_global_mouse_position()
	var gpos := _world_to_grid(cursor)
	if not _in_bounds(gpos.x, gpos.y):
		_clear_selection()
		return

	# 检查是否点击了可达格（移动）
	if _selected_id >= 0 and gpos in _reachable_tiles:
		# 检查是否可驻兵建筑
		if _turn_manager:
			var bmgr: Node = get_parent().get_node("BuildingManager2D")
			if bmgr and bmgr.has_method("can_garrison"):
				var b: Dictionary = bmgr.get_building_at(gpos)
				if not b.is_empty() and bmgr.can_garrison(b["id"], _turn_manager.current_player):
					_garrison_unit_to(b["id"], gpos)
					return
		_move_selected_to(gpos)
		return

	# 检查是否点击了己方单位（选择）
	var unit := get_unit_at(gpos)
	if not unit.is_empty():
		var current_player := 0
		if _turn_manager:
			current_player = _turn_manager.current_player
		if unit["faction"] == current_player:
			_select_unit(unit["id"])
			return

	# 点击其他 → 取消选择
	_clear_selection()


func _select_unit(uid: int) -> void:
	_clear_selection()
	_selected_id = uid
	for u in _units:
		if u["id"] == uid:
			_reachable_tiles = _calc_reachable(u)
			break
	queue_redraw()


func _clear_selection() -> void:
	_selected_id = -1
	_reachable_tiles = []
	queue_redraw()


# ========== 移动 ==========

func _move_selected_to(target: Vector2i) -> void:
	if _selected_id < 0:
		return

	for u in _units:
		if u["id"] == _selected_id:
			var from: Vector2i = u["grid_pos"]
			var steps := _calc_path_length(from, target)
			if steps <= 0:
				break

			# 扣 AP（1 AP/步，原型简化）
			if _turn_manager:
				var ok: bool = _turn_manager.spend_ap(_turn_manager.current_player, steps)
				if not ok:
					# AP 不足，回退
					break

			u["grid_pos"] = target
			u["has_moved"] = true

			# 移动后揭示视野
			var data: UnitData = u["data"]
			var fog_mgr = get_parent().get_node("FogOfWar2D")
			if fog_mgr:
				var cp: int = _turn_manager.current_player
				fog_mgr.reveal_area(cp, target.x, target.y, data.vision)

			# 工人到达资源格 → 通知采集管理器
			if data.category == UnitData.UnitCategory.WORKER:
				var gather_mgr = get_parent().get_node("GatheringManager2D")
				if gather_mgr and gather_mgr.has_method("start_gather"):
					var res_mgr = get_parent().get_node("ResourceManager2D")
					if res_mgr and res_mgr.has_method("get_gather_result"):
						var gather_info: Array = res_mgr.get_gather_result(target.x, target.y)
						if not gather_info.is_empty():
							gather_mgr.start_gather(u["faction"], target, gather_info)

			# 移动后自动取消选择
			_clear_selection()
			queue_redraw()
			break


func _calc_reachable(unit: Dictionary) -> Array:
	## BFS 从单位位置出发，max_depth = move_max
	var from: Vector2i = unit["grid_pos"]
	var data: UnitData = unit["data"]
	var max_steps: int = data.move_max
	var result: Array = []

	var visited := {}
	var depth := {}
	var queue: Array = [from]
	visited[from] = true
	depth[from] = 0

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var d: int = depth[pos]

		if d >= max_steps:
			continue

		for dir in dirs:
			var nx: int = pos.x + dir.x
			var ny: int = pos.y + dir.y
			var nkey := Vector2i(nx, ny)

			if not _in_bounds(nx, ny):
				continue
			if visited.has(nkey):
				continue
			if not _is_tile_passable(nx, ny):
				continue
			if not _is_tile_empty(nx, ny):
				# 检查是否可驻兵建筑（资源建筑、同阵营、有容量）
				var bmgr: Node = get_parent().get_node("BuildingManager2D")
				if bmgr and bmgr.has_method("get_building_at") and bmgr.has_method("max_garrison"):
					var b: Dictionary = bmgr.get_building_at(Vector2i(nx, ny))
					if not b.is_empty() and b["faction"] == unit["faction"]:
						if not b["data"].production.is_empty():
							if b.get("garrison", []).size() < bmgr.max_garrison(b):
								visited[nkey] = true
								result.append(nkey)
				continue

			visited[nkey] = true
			depth[nkey] = d + 1
			result.append(nkey)
			queue.append(nkey)

	return result


func _calc_path_length(from: Vector2i, to: Vector2i) -> int:
	## 简化的 BFS 寻路，返回最短步数，不可达返回 -1
	if from == to:
		return 0

	var visited := {}
	var queue: Array = [from]
	var dist := { from: 0 }
	visited[from] = true

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		var d: int = dist[pos]

		for dir in dirs:
			var nx: int = pos.x + dir.x
			var ny: int = pos.y + dir.y
			var nkey := Vector2i(nx, ny)

			if not _in_bounds(nx, ny):
				continue
			if visited.has(nkey):
				continue
			if not _is_tile_passable(nx, ny):
				continue

			if nkey == to:
				return d + 1

			visited[nkey] = true
			dist[nkey] = d + 1
			queue.append(nkey)

	return -1


# ========== 回合集成 ==========

func _on_player_turn_started(player: int) -> void:
	# 重置该玩家单位的移动/攻击状态
	for u in _units:
		if u["faction"] == player:
			u["has_moved"] = false
			u["has_attacked"] = false

	_clear_selection()


func _on_player_turn_ended(player: int) -> void:
	_clear_selection()


# ========== 驻兵 ==========

func _garrison_unit_to(building_id: int, target: Vector2i) -> void:
	## 将选中单位入驻到建筑内
	if _selected_id < 0:
		return

	for u in _units:
		if u["id"] == _selected_id:
			var from: Vector2i = u["grid_pos"]
			var steps := _calc_path_length(from, target)
			if steps <= 0:
				return

			# 扣 AP
			if _turn_manager:
				var ok: bool = _turn_manager.spend_ap(_turn_manager.current_player, steps)
				if not ok:
					return

			# 入驻建筑
			var bmgr: Node = get_parent().get_node("BuildingManager2D")
			if bmgr and bmgr.has_method("garrison_unit"):
				bmgr.garrison_unit(building_id, u)

			# 从单位列表移除
			_units.erase(u)
			_clear_selection()
			queue_redraw()
			return


func add_unit(faction: int, data: UnitData, grid_pos: Vector2i, hp: int = -1) -> int:
	## 公共接口：添加一个单位到地图上（用于驻兵撤出等）
	var uid := _next_id
	_next_id += 1
	_units.append({
		"id": uid,
		"data": data,
		"faction": faction,
		"grid_pos": grid_pos,
		"hp": hp if hp >= 0 else data.hp_max,
		"has_moved": false,
		"has_attacked": false,
	})
	queue_redraw()
	return uid


func get_selected_id() -> int:
	return _selected_id


# ========== 工具 ==========

func _is_tile_passable(gx: int, gy: int) -> bool:
	if _grid_manager and _grid_manager.has_method("get_terrain_at"):
		var t: int = _grid_manager.get_terrain_at(gx, gy)
		return TerrainData.is_passable(t)
	return true


func _is_tile_empty(gx: int, gy: int) -> bool:
	var pos := Vector2i(gx, gy)
	# 单位占用检查
	for u in _units:
		if u["grid_pos"] == pos:
			return false
	# 建筑占用检查
	var bmgr = get_parent().get_node("BuildingManager2D")
	if bmgr and bmgr.is_tile_occupied(gx, gy):
		return false
	return true


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < grid_cols and y >= 0 and y < grid_rows


func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	var gx := int(roundf((world_pos.x - offset.x) / tile_size))
	var gy := int(roundf((world_pos.y - offset.y) / tile_size))
	return Vector2i(gx, gy)
