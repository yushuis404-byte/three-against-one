extends Node2D

const DragonPortalConfirmPanelScript := preload("res://scripts/ui/dragon_portal_confirm_panel.gd")

signal portal_hovered(text: String)

const MAX_UNITS_PER_TELEPORT := 6
const INTERACTION_RANGE := 1
const PORTAL_SIZE := Vector2i(2, 2)
const TILE_SIZE := 32.0

var _grid_manager: Node = null
var _unit_manager: Node = null
var _turn_manager: Node = null
var _fog_manager: Node = null
var _confirm_panel: DragonPortalConfirmPanel = null
var _portal_used_this_turn: Array[bool] = [false, false, false]
var _portals: Array[Dictionary] = []
var _last_hover_text := ""


func _ready() -> void:
	z_index = 2
	_bind_siblings()
	_build_portals()
	_ensure_confirm_panel()
	set_process(true)
	queue_redraw()


func set_turn_manager(turn_manager: Node) -> void:
	if _turn_manager == turn_manager:
		return
	if _turn_manager != null and _turn_manager.has_signal("player_turn_started"):
		var old_callable := Callable(self, "_on_player_turn_started")
		if _turn_manager.player_turn_started.is_connected(old_callable):
			_turn_manager.player_turn_started.disconnect(old_callable)
	_turn_manager = turn_manager
	if _turn_manager != null and _turn_manager.has_signal("player_turn_started"):
		var new_callable := Callable(self, "_on_player_turn_started")
		if not _turn_manager.player_turn_started.is_connected(new_callable):
			_turn_manager.player_turn_started.connect(new_callable)


func _process(_delta: float) -> void:
	_update_hover_text()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _confirm_panel != null and _confirm_panel.visible:
		return
	var grid_pos: Vector2i = _world_to_grid(get_global_mouse_position())
	var portal_end: Dictionary = _get_portal_end_at(grid_pos)
	if portal_end.is_empty():
		return
	get_viewport().set_input_as_handled()
	_request_portal_use(portal_end)


func _draw() -> void:
	for portal in _portals:
		_draw_portal_end(portal, "outer")
		_draw_portal_end(portal, "inner")


func _bind_siblings() -> void:
	if get_parent() == null:
		return
	_grid_manager = get_parent().get_node_or_null("GridManager2D")
	_unit_manager = get_parent().get_node_or_null("UnitManager2D")
	_fog_manager = get_parent().get_node_or_null("FogOfWar2D")
	set_turn_manager(get_parent().get_node_or_null("TurnManager2D"))


func _build_portals() -> void:
	_portals = [
		_make_portal("north", "北侧龙门", Vector2i(49, 18), Vector2i(49, 23)),
		_make_portal("west", "西南龙门", Vector2i(40, 32), Vector2i(45, 29)),
		_make_portal("east", "东南龙门", Vector2i(58, 32), Vector2i(53, 29)),
	]


func _make_portal(id: String, display_name: String, outer_origin: Vector2i, inner_origin: Vector2i) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"outer_cells": _rect_cells(outer_origin, PORTAL_SIZE),
		"inner_cells": _rect_cells(inner_origin, PORTAL_SIZE),
		"outer_anchor": outer_origin + Vector2i(1, 1),
		"inner_anchor": inner_origin + Vector2i(1, 1),
	}


func _rect_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			cells.append(Vector2i(x, y))
	return cells


func _ensure_confirm_panel() -> void:
	if _confirm_panel != null:
		return
	var ui_root: Node = null
	if get_parent() != null and get_parent().get_parent() != null:
		ui_root = get_parent().get_parent().get_node_or_null("UI")
	if ui_root == null:
		return
	_confirm_panel = DragonPortalConfirmPanelScript.new()
	_confirm_panel.name = "DragonPortalConfirmPanel"
	_confirm_panel.z_index = 120
	ui_root.add_child(_confirm_panel)
	_confirm_panel.confirmed.connect(_on_confirm_panel_confirmed)


func _request_portal_use(portal_end: Dictionary) -> void:
	_bind_siblings()
	if _turn_manager == null or _unit_manager == null:
		_show_notice("无法使用巨龙传送门", "传送门系统尚未连接回合或单位系统。")
		return
	var player: int = int(_turn_manager.get("current_player"))
	if player < 0 or player >= _portal_used_this_turn.size():
		return
	if _portal_used_this_turn[player]:
		_show_notice("无法使用巨龙传送门", "本回合已经使用过巨龙传送门。每回合只能传入或传出一次。")
		return

	var source_cells: Array = portal_end.get("source_cells", [])
	var selected_ids: Array = _unit_manager.call("get_selected_unit_ids")
	if selected_ids.is_empty():
		_show_notice("无法使用巨龙传送门", "请先点选、追加点选或框选需要传送的己方单位。")
		return

	var eligible_ids: Array = _unit_manager.call("get_selected_units_near_cells", selected_ids, source_cells, INTERACTION_RANGE, 0)
	if eligible_ids.is_empty():
		_show_notice("无法使用巨龙传送门", "选中的单位不在传送门附近。单位需要站在传送门 1 格范围内。")
		return

	var teleport_ids: Array[int] = []
	var limit: int = mini(MAX_UNITS_PER_TELEPORT, eligible_ids.size())
	for i in range(limit):
		teleport_ids.append(int(eligible_ids[i]))

	var direction: String = str(portal_end.get("direction", "enter"))
	var target_anchor: Vector2i = portal_end.get("target_anchor", Vector2i.ZERO)
	var title := "使用巨龙传送门"
	var body := _build_confirm_body(direction, selected_ids.size(), eligible_ids.size(), teleport_ids.size())
	var payload := {
		"player": player,
		"unit_ids": teleport_ids,
		"target_anchor": target_anchor,
		"direction": direction,
	}
	if _confirm_panel == null:
		_ensure_confirm_panel()
	if _confirm_panel == null:
		_execute_portal_payload(payload)
		return
	_confirm_panel.show_request(title, body, payload, true)


func _build_confirm_body(direction: String, selected_count: int, eligible_count: int, teleport_count: int) -> String:
	var target_text := "进入巨龙巢穴内部边缘"
	if direction != "enter":
		target_text = "返回巨龙巢穴外围"
	var lines: Array[String] = []
	lines.append("将传送 %d 个单位%s。" % [teleport_count, target_text])
	if selected_count > eligible_count:
		lines.append("已选择 %d 个单位，其中 %d 个在传送门附近。" % [selected_count, eligible_count])
	if eligible_count > MAX_UNITS_PER_TELEPORT:
		lines.append("一次最多传送 %d 个单位，本次会传送距离最近的 %d 个。" % [MAX_UNITS_PER_TELEPORT, teleport_count])
	if direction == "enter":
		lines.append("巢穴内存在瘴气，没有迷障护盾时，回合开始会持续扣血并可能死亡。")
	else:
		lines.append("返回外围后不会再受到巢穴瘴气影响。")
	lines.append("本回合传送门使用后，不能再进行传入或传出。")
	return "\n".join(lines)


func _on_confirm_panel_confirmed(payload: Dictionary) -> void:
	_execute_portal_payload(payload)


func _execute_portal_payload(payload: Dictionary) -> void:
	if _turn_manager == null or _unit_manager == null:
		return
	var player: int = int(payload.get("player", -1))
	if player < 0 or player >= _portal_used_this_turn.size():
		return
	if _portal_used_this_turn[player]:
		_show_notice("无法使用巨龙传送门", "本回合已经使用过巨龙传送门。每回合只能传入或传出一次。")
		return
	if player != int(_turn_manager.get("current_player")):
		_show_notice("无法使用巨龙传送门", "当前已经不是发起传送的玩家回合。")
		return
	var unit_ids: Array = payload.get("unit_ids", [])
	var target_anchor: Vector2i = payload.get("target_anchor", Vector2i.ZERO)
	var result: Dictionary = _unit_manager.call("teleport_units_to_nearest_empty", unit_ids, target_anchor)
	if not bool(result.get("success", false)):
		_show_notice("无法使用巨龙传送门", "出口附近没有足够空格，传送没有执行。")
		return
	_portal_used_this_turn[player] = true
	queue_redraw()


func _show_notice(title: String, body: String) -> void:
	if _confirm_panel == null:
		_ensure_confirm_panel()
	if _confirm_panel != null:
		_confirm_panel.show_request(title, body, {}, false)
	else:
		print("[DragonPortal] %s: %s" % [title, body])


func _get_portal_end_at(grid_pos: Vector2i) -> Dictionary:
	for portal in _portals:
		var outer_cells: Array = portal.get("outer_cells", [])
		if grid_pos in outer_cells:
			return {
				"portal_id": str(portal.get("id", "")),
				"source_cells": outer_cells,
				"target_anchor": portal.get("inner_anchor", Vector2i.ZERO),
				"direction": "enter",
			}
		var inner_cells: Array = portal.get("inner_cells", [])
		if grid_pos in inner_cells:
			return {
				"portal_id": str(portal.get("id", "")),
				"source_cells": inner_cells,
				"target_anchor": portal.get("outer_anchor", Vector2i.ZERO),
				"direction": "exit",
			}
	return {}


func _draw_portal_end(portal: Dictionary, side: String) -> void:
	var cells: Array = portal.get("%s_cells" % side, [])
	var anchor: Vector2i = portal.get("%s_anchor" % side, Vector2i.ZERO)
	var color := Color(0.20, 0.78, 1.0, 0.72)
	var border := Color(0.80, 0.95, 1.0, 0.92)
	if side != "outer":
		color = Color(0.72, 0.40, 1.0, 0.72)
		border = Color(0.92, 0.82, 1.0, 0.92)
	for cell_variant in cells:
		var cell: Vector2i = cell_variant
		var center := _grid_to_world(cell.x, cell.y)
		var rect := Rect2(center - Vector2(TILE_SIZE, TILE_SIZE) * 0.5, Vector2(TILE_SIZE, TILE_SIZE))
		draw_rect(rect.grow(-3.0), Color(color.r, color.g, color.b, 0.28), true)
		draw_rect(rect.grow(-3.0), border, false, 1.4)
	var portal_center := _grid_to_world(anchor.x, anchor.y) - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	draw_circle(portal_center, 19.0, Color(color.r, color.g, color.b, 0.24))
	draw_arc(portal_center, 19.0, 0.0, TAU, 48, border, 2.5, true)
	var font: Font = ThemeDB.fallback_font
	var label := "龙门"
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, portal_center - Vector2(text_size.x * 0.5, -4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.94, 0.97, 1.0, 0.95))


func _update_hover_text() -> void:
	var grid_pos: Vector2i = _world_to_grid(get_global_mouse_position())
	var portal_end: Dictionary = _get_portal_end_at(grid_pos)
	var text := ""
	if not portal_end.is_empty():
		text = "巨龙传送门：点击后传送选中的附近单位"
	if text == _last_hover_text:
		return
	_last_hover_text = text
	portal_hovered.emit(text)


func _on_player_turn_started(player: int) -> void:
	if player < 0 or player >= _portal_used_this_turn.size():
		return
	_portal_used_this_turn[player] = false


func _grid_to_world(grid_x: int, grid_y: int) -> Vector2:
	if _grid_manager != null and _grid_manager.has_method("grid_to_world"):
		return _grid_manager.call("grid_to_world", grid_x, grid_y)
	var offset := Vector2(-49.5 * TILE_SIZE, -27.5 * TILE_SIZE)
	return Vector2(grid_x * TILE_SIZE + offset.x, grid_y * TILE_SIZE + offset.y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	if _grid_manager != null and _grid_manager.has_method("world_to_grid"):
		return _grid_manager.call("world_to_grid", world_pos)
	var offset := Vector2(-49.5 * TILE_SIZE, -27.5 * TILE_SIZE)
	return Vector2i(int(roundf((world_pos.x - offset.x) / TILE_SIZE)), int(roundf((world_pos.y - offset.y) / TILE_SIZE)))
