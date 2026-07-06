extends Node2D

const TILE_SIZE := 32.0
const GRID_CENTER := Vector2(49.5, 27.5)
const GATHER_DURATION := 5.0
const GATHER_AP_COST := 1

var _turn_mgr: Node = null
var _unit_mgr: Node = null
var _res_mgr: Node = null
var _tracker: Node = null
var _network_game_service: Node = null

var _active_gathers: Dictionary = {}


func _ready() -> void:
	_turn_mgr = get_parent().get_node("TurnManager2D")
	_unit_mgr = get_parent().get_node("UnitManager2D")
	_res_mgr = get_parent().get_node("ResourceManager2D")
	_tracker = get_parent().get_node("ResourceTracker")
	set_process(true)
	if _turn_mgr != null and _turn_mgr.has_signal("player_turn_ended"):
		_turn_mgr.player_turn_ended.connect(_on_player_turn_ended)


func _process(delta: float) -> void:
	if _active_gathers.is_empty():
		return
	var completed_ids: Array[int] = []
	var canceled_ids: Array[int] = []
	for unit_id_variant in _active_gathers.keys():
		var unit_id: int = int(unit_id_variant)
		var gather: Dictionary = _active_gathers[unit_id]
		var player: int = int(gather.get("faction", -1))
		if _is_player_ready(player):
			canceled_ids.append(unit_id)
			continue
		gather["elapsed"] = float(gather.get("elapsed", 0.0)) + delta
		_active_gathers[unit_id] = gather
		if float(gather.get("elapsed", 0.0)) >= GATHER_DURATION:
			completed_ids.append(unit_id)
	for unit_id in canceled_ids:
		cancel_gather(unit_id)
	for unit_id in completed_ids:
		_complete_gather(unit_id)
	queue_redraw()


func set_network_game_service(service: Node) -> void:
	_network_game_service = service


func start_gather(unit_id: int, faction: int, pos: Vector2i, info: Array) -> bool:
	if unit_id < 0 or info.is_empty():
		return false
	var unit: Dictionary = _get_unit(unit_id)
	if unit.is_empty() or int(unit.get("faction", -1)) != faction:
		return false
	if unit.get("grid_pos", Vector2i(-1, -1)) != pos:
		return false
	cancel_gather(unit_id)
	_active_gathers[unit_id] = {
		"unit_id": unit_id,
		"faction": faction,
		"pos": pos,
		"info": info.duplicate(true),
		"elapsed": 0.0,
	}
	queue_redraw()
	return true


func cancel_gather(unit_id: int) -> void:
	if _active_gathers.erase(unit_id):
		queue_redraw()


func cancel_gathers_for_units(unit_ids: Array) -> void:
	var changed := false
	for raw_id in unit_ids:
		changed = _active_gathers.erase(int(raw_id)) or changed
	if changed:
		queue_redraw()


func cancel_gathers_for_player(player: int) -> void:
	var changed := false
	for unit_id_variant in _active_gathers.keys():
		var unit_id: int = int(unit_id_variant)
		var gather: Dictionary = _active_gathers[unit_id]
		if int(gather.get("faction", -1)) == player:
			changed = _active_gathers.erase(unit_id) or changed
	if changed:
		queue_redraw()


func is_unit_gathering(unit_id: int) -> bool:
	return _active_gathers.has(unit_id)


func apply_network_gather_complete(player: int, unit_id: int, pos: Vector2i, results: Array) -> void:
	cancel_gather(unit_id)
	if _tracker != null:
		for result_variant in results:
			var entry: Dictionary = result_variant
			_tracker.add_resource(player, str(entry.get("key", "")), int(entry.get("amount", 0)))
	if _res_mgr != null and _res_mgr.has_method("remove_resource"):
		_res_mgr.remove_resource(pos.x, pos.y)
	_show_gather_text(pos, results)
	queue_redraw()


func _on_player_turn_ended(player: int) -> void:
	cancel_gathers_for_player(player)


func _complete_gather(unit_id: int) -> void:
	if not _active_gathers.has(unit_id):
		return
	var gather: Dictionary = _active_gathers[unit_id]
	_active_gathers.erase(unit_id)
	var player: int = int(gather.get("faction", -1))
	var pos: Vector2i = gather.get("pos", Vector2i(-1, -1))
	var previous_current_player: int = int(_turn_mgr.get("current_player")) if _turn_mgr != null else -1
	var previous_view_player: int = int(_turn_mgr.get("view_player")) if _turn_mgr != null else -1
	if _is_network_client():
		queue_redraw()
		return
	if not _can_complete_gather(unit_id, player, pos):
		queue_redraw()
		return
	var results: Array = _res_mgr.get_gather_result(pos.x, pos.y) if _res_mgr != null and _res_mgr.has_method("get_gather_result") else []
	if results.is_empty():
		queue_redraw()
		return
	if _turn_mgr != null and _turn_mgr.has_method("spend_ap"):
		if not bool(_turn_mgr.call("spend_ap", player, GATHER_AP_COST)):
			queue_redraw()
			return
	if _tracker != null:
		for result_variant in results:
			var entry: Dictionary = result_variant
			_tracker.add_resource(player, str(entry.get("key", "")), int(entry.get("amount", 0)))
	if _res_mgr != null and _res_mgr.has_method("remove_resource"):
		_res_mgr.remove_resource(pos.x, pos.y)
	_show_gather_text(pos, results)
	if _network_game_service != null and _network_game_service.has_method("broadcast_gather_complete"):
		_network_game_service.call("broadcast_gather_complete", player, unit_id, pos, results)
	_restore_turn_view_after_gather(previous_current_player, previous_view_player)
	queue_redraw()


func _restore_turn_view_after_gather(previous_current_player: int, previous_view_player: int) -> void:
	if _turn_mgr == null:
		return
	if previous_current_player >= 0:
		_turn_mgr.set("current_player", previous_current_player)
	if previous_view_player >= 0:
		_turn_mgr.set("view_player", previous_view_player)
		if _turn_mgr.has_signal("view_player_changed"):
			_turn_mgr.emit_signal("view_player_changed", previous_view_player)


func _can_complete_gather(unit_id: int, player: int, pos: Vector2i) -> bool:
	if player < 0:
		return false
	var unit: Dictionary = _get_unit(unit_id)
	if unit.is_empty() or int(unit.get("faction", -1)) != player:
		return false
	if unit.get("grid_pos", Vector2i(-1, -1)) != pos:
		return false
	if _res_mgr == null or not _res_mgr.has_method("get_gather_result"):
		return false
	var results: Array = _res_mgr.get_gather_result(pos.x, pos.y)
	if results.is_empty():
		return false
	if not _can_unit_complete_gather(_get_unit_data(unit), results):
		return false
	return true


func _draw() -> void:
	for unit_id_variant in _active_gathers.keys():
		var unit_id: int = int(unit_id_variant)
		var gather: Dictionary = _active_gathers[unit_id]
		var unit: Dictionary = _get_unit(unit_id)
		if unit.is_empty() or not _is_unit_visible(unit):
			continue
		var pos: Vector2i = unit.get("grid_pos", gather.get("pos", Vector2i.ZERO))
		var world_pos := _grid_to_world(pos.x, pos.y) + Vector2(0, -20)
		var progress := clampf(float(gather.get("elapsed", 0.0)) / GATHER_DURATION, 0.0, 1.0)
		draw_circle(world_pos, 10.0, Color(0.05, 0.10, 0.08, 0.55))
		draw_arc(world_pos, 10.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, Color(0.55, 1.0, 0.46, 0.95), 2.5)
		draw_arc(world_pos, 10.0, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.65), 1.0)


func _is_unit_visible(unit: Dictionary) -> bool:
	if _turn_mgr == null:
		return true
	var viewer: int = int(_turn_mgr.get("view_player"))
	if int(unit.get("faction", -1)) == viewer:
		return true
	if _unit_mgr != null and _unit_mgr.has_method("get_visible_unit_at"):
		var pos: Vector2i = unit.get("grid_pos", Vector2i(-1, -1))
		var visible_unit: Dictionary = _unit_mgr.call("get_visible_unit_at", pos)
		return not visible_unit.is_empty() and int(visible_unit.get("id", -1)) == int(unit.get("id", -2))
	return false


func _get_unit(unit_id: int) -> Dictionary:
	if _unit_mgr == null or not _unit_mgr.has_method("get_unit_by_id"):
		return {}
	return _unit_mgr.call("get_unit_by_id", unit_id)


func _get_unit_data(unit: Dictionary) -> UnitData:
	if unit.has("data") and unit["data"] is UnitData:
		return unit["data"]
	return UnitData.worker()


func _can_unit_complete_gather(data: UnitData, gather_info: Array) -> bool:
	if data.category == UnitData.UnitCategory.WORKER:
		return true
	for result_variant in gather_info:
		var entry: Dictionary = result_variant
		if str(entry.get("key", "")) == "food":
			return true
	return false


func _is_network_client() -> bool:
	if _network_game_service == null:
		return false
	if not _network_game_service.has_method("is_network_game") or not bool(_network_game_service.call("is_network_game")):
		return false
	if not _network_game_service.has_method("is_host"):
		return false
	return not bool(_network_game_service.call("is_host"))


func _is_player_ready(player: int) -> bool:
	if _turn_mgr == null or not _turn_mgr.has_method("is_player_ready"):
		return false
	return bool(_turn_mgr.call("is_player_ready", player))


func _show_gather_text(grid_pos: Vector2i, results: Array) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	var icon_size := 12.0
	for result_variant in results:
		var entry: Dictionary = result_variant
		var rkey: String = str(entry.get("key", ""))
		var display: String = GameCatalog.resource_name(rkey)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icon_" + rkey + ".png")
		if icon.texture != null:
			icon.custom_minimum_size = Vector2(icon_size, icon_size)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = "+%d %s" % [int(entry.get("amount", 0)), display]
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 10)
		row.add_child(label)
		container.add_child(row)
	var world_pos := _grid_to_world(grid_pos.x, grid_pos.y)
	container.position = Vector2(world_pos.x - 40, world_pos.y - 30)
	add_child(container)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(container, "position", container.position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 1.0)
	tween.tween_callback(container.queue_free)



func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	var offset := Vector2(-GRID_CENTER.x * TILE_SIZE, -GRID_CENTER.y * TILE_SIZE)
	return Vector2(grid_x * TILE_SIZE + offset.x, grid_y * TILE_SIZE + offset.y)
