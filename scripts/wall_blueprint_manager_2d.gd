extends Node2D

signal wall_hovered(text: String)
signal wall_blueprint_confirmed(player: int, wall_id: int, segments: Array)
signal wall_mode_changed(active: bool, message: String)
signal wall_preview_changed(message: String, valid: bool, cells: int, stone_cost: int)

const DWARF_PLAYER := 1
const STONE_COST_PER_SEGMENT := 3
const IRON_COST_PER_UPGRADE := 1
const WALL_LEVEL_1_HP := 8
const WALL_LEVEL_2_HP := 14
const WALL_THICKNESS := 8.0
const WALL_STRAIGHT_LENGTH := 34.0
const WALL_DIAGONAL_LENGTH := 48.0

var grid_cols := 100
var grid_rows := 56
var tile_size := 32.0
var grid_center := Vector2(49.5, 27.5)

var _turn_manager: Node = null
var _building_manager: Node = null
var _resource_tracker: Node = null
var _grid_manager: Node = null
var _fog_manager: Node = null

var _walls: Array[Dictionary] = []
var _next_wall_id := 1

var _anchor_mode := false
var _start_building: Dictionary = {}
var _end_building: Dictionary = {}
var _preview_cells: Array[Vector2i] = []
var _preview_valid := false
var _preview_message := ""
var _last_hovered_wall_cell := Vector2i(-1, -1)
var _preview_start_cell := Vector2i(-1, -1)
var _preview_end_cell := Vector2i(-1, -1)


func _ready() -> void:
	_grid_manager = get_parent().get_node_or_null("GridManager2D")
	_building_manager = get_parent().get_node_or_null("BuildingManager2D")
	_resource_tracker = get_parent().get_node_or_null("ResourceTracker")
	_turn_manager = get_parent().get_node_or_null("TurnManager2D")
	_fog_manager = get_parent().get_node_or_null("FogOfWar2D")
	if _fog_manager != null and _fog_manager.has_signal("fog_updated"):
		var callback := Callable(self, "_on_fog_updated")
		if not _fog_manager.fog_updated.is_connected(callback):
			_fog_manager.fog_updated.connect(_on_fog_updated)


func set_turn_manager(turn_manager: Node) -> void:
	_turn_manager = turn_manager


func set_resource_tracker(resource_tracker: Node) -> void:
	_resource_tracker = resource_tracker


func set_building_manager(building_manager: Node) -> void:
	_building_manager = building_manager


func _on_fog_updated(_player: int) -> void:
	queue_redraw()


func get_all_walls() -> Array:
	return _walls.duplicate(true)


func start_wall_anchor_selection() -> void:
	if _current_player() != DWARF_PLAYER:
		return
	_anchor_mode = true
	_start_building = {}
	_end_building = {}
	_preview_start_cell = Vector2i(-1, -1)
	_preview_end_cell = Vector2i(-1, -1)
	_preview_cells.clear()
	_preview_valid = false
	_preview_message = "\u9009\u62e9\u7b2c\u4e00\u4e2a\u77ee\u4eba\u5efa\u7b51"
	wall_hovered.emit(_preview_message)
	wall_mode_changed.emit(true, _preview_message)
	_emit_preview_changed()
	queue_redraw()


func cancel_wall_blueprint() -> void:
	_anchor_mode = false
	_start_building = {}
	_end_building = {}
	_preview_start_cell = Vector2i(-1, -1)
	_preview_end_cell = Vector2i(-1, -1)
	_preview_cells.clear()
	_preview_valid = false
	_preview_message = ""
	wall_hovered.emit("")
	wall_mode_changed.emit(false, "")
	_emit_preview_changed()
	queue_redraw()


func confirm_wall_blueprint() -> bool:
	if not _anchor_mode or _preview_cells.is_empty() or not _preview_valid:
		return false
	var player := _current_player()
	var cost := get_preview_stone_cost()
	if _resource_tracker == null or not _resource_tracker.has_method("spend_resource"):
		return false
	if not _resource_tracker.spend_resource(player, "stone", cost):
		_preview_message = "\u77f3\u6599\u4e0d\u8db3: \u9700\u8981 %d" % cost
		wall_hovered.emit(_preview_message)
		queue_redraw()
		return false
	var wall_id := _next_wall_id
	_next_wall_id += 1
	var segments: Array = []
	for i in range(_preview_cells.size()):
		var cell: Vector2i = _preview_cells[i]
		var direction := _segment_dir_for_index(i, _preview_cells, _preview_start_cell, _preview_end_cell)
		segments.append({
			"cell": cell,
			"dir": direction,
			"level": 1,
			"hp": WALL_LEVEL_1_HP,
			"hp_max": WALL_LEVEL_1_HP,
		})
	_walls.append({
		"id": wall_id,
		"faction": player,
		"start_building_id": int(_start_building.get("id", -1)),
		"end_building_id": int(_end_building.get("id", -1)),
		"segments": segments,
	})
	wall_blueprint_confirmed.emit(player, wall_id, segments.duplicate(true))
	cancel_wall_blueprint()
	queue_redraw()
	return true


func get_preview_stone_cost() -> int:
	return _preview_cells.size() * STONE_COST_PER_SEGMENT


func upgrade_wall_segment(wall_id: int, cell: Vector2i) -> bool:
	var player := _current_player()
	for wall in _walls:
		if int(wall.get("id", -1)) != wall_id or int(wall.get("faction", -1)) != player:
			continue
		var segments: Array = wall.get("segments", [])
		for i in range(segments.size()):
			var segment: Dictionary = segments[i]
			if Vector2i(segment.get("cell", Vector2i(-1, -1))) != cell:
				continue
			if int(segment.get("level", 1)) >= 2:
				return false
			if _resource_tracker == null or not _resource_tracker.spend_resource(player, "iron", IRON_COST_PER_UPGRADE):
				return false
			segment["level"] = 2
			segment["hp"] = WALL_LEVEL_2_HP
			segment["hp_max"] = WALL_LEVEL_2_HP
			segments[i] = segment
			wall["segments"] = segments
			queue_redraw()
			return true
	return false


func has_wall_at(cell: Vector2i) -> bool:
	return not get_wall_segment_at(cell).is_empty()


func blocks_movement_at(cell: Vector2i) -> bool:
	return has_wall_at(cell)


func is_wall_mode_active() -> bool:
	return _anchor_mode


func get_wall_mode_message() -> String:
	return _preview_message


func get_wall_segment_at(cell: Vector2i) -> Dictionary:
	for wall in _walls:
		var segments: Array = wall.get("segments", [])
		for segment in segments:
			var segment_dict: Dictionary = segment
			if Vector2i(segment_dict.get("cell", Vector2i(-1, -1))) == cell:
				var result := segment_dict.duplicate(true)
				result["wall_id"] = int(wall.get("id", -1))
				result["faction"] = int(wall.get("faction", -1))
				return result
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if not _anchor_mode:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_wall_blueprint()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_anchor_click(_world_to_grid(get_global_mouse_position()))
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		if not _start_building.is_empty() and _end_building.is_empty():
			_update_preview_to_cell(_world_to_grid(get_global_mouse_position()))
		elif _start_building.is_empty():
			_update_wall_hover(_world_to_grid(get_global_mouse_position()))
		return


func _draw() -> void:
	_draw_confirmed_walls()
	_draw_preview()


func _handle_anchor_click(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	var building := _get_owned_dwarf_building_at(cell)
	if building.is_empty():
		return
	if _start_building.is_empty():
		_start_building = building
		_preview_message = "\u9009\u62e9\u7b2c\u4e8c\u4e2a\u77ee\u4eba\u5efa\u7b51"
		wall_hovered.emit(_preview_message)
		_emit_preview_changed()
		queue_redraw()
		return
	if int(building.get("id", -1)) == int(_start_building.get("id", -1)):
		return
	_end_building = building
	_update_preview_between_buildings()


func _update_preview_between_buildings() -> void:
	if _start_building.is_empty() or _end_building.is_empty():
		return
	var start := _building_center(_start_building)
	var end := _building_center(_end_building)
	_preview_start_cell = start
	_preview_end_cell = end
	_preview_cells = _build_eight_direction_line(start, end)
	_preview_valid = _validate_preview()
	_update_preview_message()
	queue_redraw()


func _update_preview_to_cell(cell: Vector2i) -> void:
	if _start_building.is_empty() or not _in_bounds(cell):
		return
	var start := _building_center(_start_building)
	_preview_start_cell = start
	_preview_end_cell = cell
	_preview_cells = _build_eight_direction_line(start, cell)
	_preview_valid = _validate_preview()
	_update_preview_message()
	queue_redraw()


func _validate_preview() -> bool:
	if _preview_cells.is_empty():
		return false
	var player: int = _current_player()
	for cell in _preview_cells:
		if not _in_bounds(cell):
			return false
		if has_wall_at(cell):
			return false
		if _grid_manager != null and _grid_manager.has_method("is_passable"):
			if not bool(_grid_manager.call("is_passable", cell.x, cell.y)):
				return false
		var building: Dictionary = _get_building_at(cell)
		if not building.is_empty():
			var bid: int = int(building.get("id", -1))
			if bid != int(_start_building.get("id", -1)) and bid != int(_end_building.get("id", -1)):
				return false
	if _resource_tracker != null and _resource_tracker.has_method("get_resource"):
		return int(_resource_tracker.get_resource(player, "stone")) >= get_preview_stone_cost()
	return true


func _update_preview_message() -> void:
	var cost: int = get_preview_stone_cost()
	var state: String = "\u65e0\u6548"
	if _preview_valid:
		state = "\u53ef\u786e\u8ba4"
	_preview_message = "\u57ce\u5899\u84dd\u56fe: %d \u683c | \u77f3\u6599 %d | %s | \u53f3\u4e0b\u89d2\u6309\u94ae\u786e\u8ba4 / \u53f3\u952e\u53d6\u6d88" % [_preview_cells.size(), cost, state]
	wall_hovered.emit(_preview_message)
	_emit_preview_changed()


func _emit_preview_changed() -> void:
	wall_preview_changed.emit(_preview_message, _preview_valid, _preview_cells.size(), get_preview_stone_cost())


func _update_wall_hover(cell: Vector2i) -> void:
	if cell == _last_hovered_wall_cell:
		return
	_last_hovered_wall_cell = cell
	if not _is_cell_visible_to_current_player(cell):
		wall_hovered.emit("")
		return
	var segment: Dictionary = get_wall_segment_at(cell)
	if segment.is_empty():
		return
	var level: int = int(segment.get("level", 1))
	var hp: int = int(segment.get("hp", 0))
	var hp_max: int = int(segment.get("hp_max", 0))
	var text: String = "\u77ee\u4eba\u57ce\u5899 Lv%d HP:%d/%d" % [level, hp, hp_max]
	if level < 2:
		text += " | \u53ef\u7528 1 \u94c1\u52a0\u56fa"
	wall_hovered.emit(text)


func _draw_confirmed_walls() -> void:
	for wall in _walls:
		var segments: Array = wall.get("segments", [])
		for segment in segments:
			var segment_dict: Dictionary = segment
			var cell: Vector2i = segment_dict.get("cell", Vector2i(-1, -1))
			if not _is_cell_visible_to_current_player(cell):
				continue
			var color: Color = Color(0.42, 0.43, 0.44, 0.88)
			var border: Color = Color(0.76, 0.78, 0.80, 0.95)
			if int(segment_dict.get("level", 1)) >= 2:
				color = Color(0.48, 0.52, 0.56, 0.95)
				border = Color(0.82, 0.88, 0.95, 1.0)
			_draw_wall_shadow(segment_dict)
			_draw_wall_segment(segment_dict, color, border, true)
			_draw_wall_caps(segment_dict, border)


func _draw_preview() -> void:
	if _preview_cells.is_empty():
		return
	for i in range(_preview_cells.size()):
		var cell: Vector2i = _preview_cells[i]
		var direction: Vector2i = _segment_dir_for_index(i, _preview_cells, _preview_start_cell, _preview_end_cell)
		var segment: Dictionary = {"cell": cell, "dir": direction}
		var color: Color = Color(1.0, 0.18, 0.16, 0.16)
		var border: Color = Color(1.0, 0.32, 0.26, 0.86)
		if _preview_valid:
			color = Color(0.2, 0.62, 1.0, 0.20)
			border = Color(0.45, 0.82, 1.0, 0.92)
		_draw_wall_segment(segment, color, border, false)
		_draw_blueprint_center_line(segment, border)


func _draw_wall_segment(segment: Dictionary, fill: Color, border: Color, filled: bool) -> void:
	var cell: Vector2i = segment.get("cell", Vector2i.ZERO)
	var direction: Vector2i = segment.get("dir", Vector2i.RIGHT)
	var center: Vector2 = _grid_to_world(cell.x, cell.y)
	var angle: float = atan2(float(direction.y), float(direction.x))
	var length: float = WALL_STRAIGHT_LENGTH
	if direction.x != 0 and direction.y != 0:
		length = WALL_DIAGONAL_LENGTH
	var rect: Rect2 = Rect2(Vector2(-length * 0.5, -WALL_THICKNESS * 0.5), Vector2(length, WALL_THICKNESS))
	draw_set_transform(center, angle, Vector2.ONE)
	draw_rect(rect, fill, filled)
	draw_rect(rect, border, false, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_wall_shadow(segment: Dictionary) -> void:
	var cell: Vector2i = segment.get("cell", Vector2i.ZERO)
	var direction: Vector2i = segment.get("dir", Vector2i.RIGHT)
	var center: Vector2 = _grid_to_world(cell.x, cell.y) + Vector2(2.0, 3.0)
	var angle: float = atan2(float(direction.y), float(direction.x))
	var length: float = WALL_STRAIGHT_LENGTH
	if direction.x != 0 and direction.y != 0:
		length = WALL_DIAGONAL_LENGTH
	var rect: Rect2 = Rect2(Vector2(-length * 0.5, -WALL_THICKNESS * 0.5), Vector2(length, WALL_THICKNESS))
	draw_set_transform(center, angle, Vector2.ONE)
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.25), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_wall_caps(segment: Dictionary, color: Color) -> void:
	var cell: Vector2i = segment.get("cell", Vector2i.ZERO)
	var direction: Vector2i = segment.get("dir", Vector2i.RIGHT)
	var center: Vector2 = _grid_to_world(cell.x, cell.y)
	var angle: float = atan2(float(direction.y), float(direction.x))
	var length: float = WALL_STRAIGHT_LENGTH
	if direction.x != 0 and direction.y != 0:
		length = WALL_DIAGONAL_LENGTH
	var cap_size: Vector2 = Vector2(3.0, WALL_THICKNESS + 2.0)
	draw_set_transform(center, angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(-length * 0.5 - 1.0, -cap_size.y * 0.5), cap_size), color, true)
	draw_rect(Rect2(Vector2(length * 0.5 - 2.0, -cap_size.y * 0.5), cap_size), color, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_blueprint_center_line(segment: Dictionary, color: Color) -> void:
	var cell: Vector2i = segment.get("cell", Vector2i.ZERO)
	var direction: Vector2i = segment.get("dir", Vector2i.RIGHT)
	var center: Vector2 = _grid_to_world(cell.x, cell.y)
	var dir: Vector2 = Vector2(float(direction.x), float(direction.y)).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var length: float = WALL_STRAIGHT_LENGTH
	if direction.x != 0 and direction.y != 0:
		length = WALL_DIAGONAL_LENGTH
	draw_line(center - dir * length * 0.5, center + dir * length * 0.5, Color(color.r, color.g, color.b, 0.42), 1.0, true)


func _build_eight_direction_line(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := start
	var guard := 0
	while current != end and guard < grid_cols + grid_rows:
		var delta := end - current
		var step := Vector2i(signi(delta.x), signi(delta.y))
		current += step
		if current != end:
			result.append(current)
		guard += 1
	return result


func _segment_dir_for_index(index: int, cells: Array[Vector2i], start_cell: Vector2i = Vector2i(-1, -1), end_cell: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	if cells.is_empty():
		return _safe_direction(end_cell - start_cell)
	if cells.size() == 1:
		return _safe_direction(end_cell - start_cell)
	var from_cell: Vector2i = start_cell if index == 0 and _in_bounds(start_cell) else cells[maxi(index - 1, 0)]
	var to_cell: Vector2i = end_cell if index == cells.size() - 1 and _in_bounds(end_cell) else cells[mini(index + 1, cells.size() - 1)]
	var delta := to_cell - from_cell
	return _safe_direction(delta)


func _safe_direction(delta: Vector2i) -> Vector2i:
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	if direction == Vector2i.ZERO:
		return Vector2i.RIGHT
	return direction


func _get_owned_dwarf_building_at(cell: Vector2i) -> Dictionary:
	var building := _get_building_at(cell)
	if building.is_empty():
		return {}
	if int(building.get("faction", -1)) != DWARF_PLAYER:
		return {}
	if _current_player() != DWARF_PLAYER:
		return {}
	return building


func _get_building_at(cell: Vector2i) -> Dictionary:
	if _building_manager != null and _building_manager.has_method("get_building_at"):
		return _building_manager.get_building_at(cell)
	return {}


func _building_center(building: Dictionary) -> Vector2i:
	var origin: Vector2i = building.get("origin", Vector2i.ZERO)
	var data: BuildingData = building.get("data", null)
	if data == null:
		return origin
	return Vector2i(origin.x + data.footprint.x / 2, origin.y + data.footprint.y / 2)


func _current_player() -> int:
	if _turn_manager != null:
		return int(_turn_manager.current_player)
	return -1


func _is_cell_visible_to_current_player(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	if _fog_manager == null or not _fog_manager.has_method("get_fog"):
		return true
	var player := _current_player()
	if player < 0:
		return true
	return float(_fog_manager.call("get_fog", player, cell.x, cell.y)) <= 0.0


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_cols and cell.y >= 0 and cell.y < grid_rows


func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	return Vector2(grid_x * tile_size + offset.x, grid_y * tile_size + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var offset := Vector2(-grid_center.x * tile_size, -grid_center.y * tile_size)
	var gx := int(roundf((world_pos.x - offset.x) / tile_size))
	var gy := int(roundf((world_pos.y - offset.y) / tile_size))
	return Vector2i(gx, gy)
